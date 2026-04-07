import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show MissingPluginException, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import 'add_client_page.dart';
import 'client_revenue_actions_page.dart';

class DealRoomWidget extends StatefulWidget {
  final VoidCallback? onClientActionLogged;

  const DealRoomWidget({super.key, this.onClientActionLogged});

  @override
  State<DealRoomWidget> createState() => _DealRoomWidgetState();
}

class _DealRoomWidgetState extends State<DealRoomWidget> {
  static const String _dealRoomTemplateAsset =
      'assets/templates/deal_room_clients_template.xlsx';

  bool _isLoading = true;
  bool _hasClients = true;
  List<dynamic> _clients = [];
  List<dynamic> _originalClients = [];
  bool _sortByPriority = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final statusRes = await ApiClient.get(
        ApiEndpoints.clientsStatus,
        requiresAuth: true,
      );

      final hasClients =
          statusRes['success'] == true &&
          (statusRes['has_clients'] == true ||
              (statusRes['clients_count'] ?? 0) > 0);

      setState(() => _hasClients = hasClients);

      if (hasClients) {
        final clientsRes = await ApiClient.get(
          '${ApiEndpoints.results}?type=hot_lead',
          requiresAuth: true,
        );
        if (clientsRes['success'] == true) {
          final data = (clientsRes['data'] ?? []) as List<dynamic>;
          // Keep an original copy so we can toggle sorting on/off
          _originalClients = List<dynamic>.from(data);
          _clients = List<dynamic>.from(_originalClients);
          _applySort();
        } else {
          _originalClients = [];
          _clients = [];
        }
      } else {
        _originalClients = [];
        _clients = [];
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSortByPriority() {
    setState(() {
      _sortByPriority = !_sortByPriority;
      _applySort();
    });
  }

  void _applySort() {
    if (_clients.isEmpty) return;

    if (!_sortByPriority) {
      // Restore original ordering from API
      _clients = List<dynamic>.from(_originalClients);
      return;
    }

    final sorted = List<dynamic>.from(_originalClients);

    sorted.sort((a, b) {
      final int pa = _extractPriority(a);
      final int pb = _extractPriority(b);
      // Higher priority (3) first
      final int byPriority = pb.compareTo(pa);
      if (byPriority != 0) return byPriority;

      final int da = _extractTodayPercent(a);
      final int db = _extractTodayPercent(b);
      // Higher completion percentage first
      return db.compareTo(da);
    });

    _clients = sorted;
  }

  int _extractPriority(dynamic client) {
    int priority = 1;
    if (client is Map && client['notes'] is String) {
      final notes = client['notes'] as String;
      if (notes.isNotEmpty) {
        try {
          final parsed = jsonDecode(notes);
          if (parsed is Map) {
            final dynamic rawPriority = parsed['priority_level'];
            if (rawPriority is num) {
              priority = rawPriority.toInt().clamp(1, 3);
            } else if (rawPriority is String) {
              final parsedInt = int.tryParse(rawPriority);
              if (parsedInt != null) {
                priority = parsedInt.clamp(1, 3);
              }
            }
          }
        } catch (_) {}
      }
    }
    return priority;
  }

  int _extractTodayPercent(dynamic client) {
    if (client is! Map) return 0;
    final progress = client['today_progress'];
    if (progress is Map<String, dynamic>) {
      final value = progress['percentage'];
      if (value is int) return value.clamp(0, 100);
      if (value is num) return value.toInt().clamp(0, 100);
    }
    return 0;
  }

  String? _readLeadStageRaw(dynamic client) {
    if (client is! Map) return null;
    final notes = client['notes'];
    if (notes is! String || notes.isEmpty) return null;
    try {
      final m = jsonDecode(notes);
      if (m is! Map) return null;
      final raw = m['lead_stage']?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  /// CRM stage shown on the client tile chip (consistent wording).
  String _stageChipLabel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Cold calling';
    final t = raw.toLowerCase();
    if (t.contains('site') || t.contains('visite')) return 'Deal negotiation';
    if (t.contains('clint')) return 'Client meeting';
    if (t.contains('cold')) return 'Cold calling';
    if (t.contains('follow')) return 'Follow-up';
    if (t.contains('client meeting')) return 'Client meeting';
    if (t.contains('negotiation')) return 'Deal negotiation';
    if (t.contains('deal close') || t == 'deal close') return 'Deal closure';
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _stageAccentColor(String? raw) {
    if (raw == null || raw.isEmpty) return const Color(0xFF2563EB);
    final t = raw.toLowerCase();
    if (t.contains('cold')) return const Color(0xFF2563EB);
    if (t.contains('follow')) return const Color(0xFF0D9488);
    if (t.contains('client meeting') || t.contains('clint'))
      return const Color(0xFF7C3AED);
    if (t.contains('negotiation') ||
        t.contains('site') ||
        t.contains('visite')) {
      return const Color(0xFFEA580C);
    }
    if (t.contains('deal close') ||
        (t.contains('close') && t.contains('deal'))) {
      return const Color(0xFF16A34A);
    }
    return const Color(0xFF64748B);
  }

  _SourceChipData _sourceChipData(dynamic sourceRaw) {
    final raw = (sourceRaw ?? '').toString().trim();
    if (raw.isEmpty) {
      return const _SourceChipData(
        label: 'Unknown',
        icon: Icons.help_outline_rounded,
        color: Color(0xFF64748B),
      );
    }

    final s = raw.toLowerCase();
    if (s.contains('whatsapp') || s == 'wa') {
      return const _SourceChipData(
        label: 'WhatsApp',
        icon: FontAwesomeIcons.whatsapp,
        color: Color(0xFF16A34A),
        isFa: true,
      );
    }
    if (s.contains('insta')) {
      return const _SourceChipData(
        label: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        color: Color(0xFFDB2777),
        isFa: true,
      );
    }
    if (s.contains('cold') || s.contains('call') || s.contains('phone')) {
      return const _SourceChipData(
        label: 'Cold call',
        icon: Icons.call_rounded,
        color: Color(0xFF2563EB),
      );
    }
    if (s.contains('content')) {
      return const _SourceChipData(
        label: 'Content',
        icon: Icons.movie_creation_outlined,
        color: Color(0xFF7C3AED),
      );
    }
    if (s.contains('referral')) {
      return const _SourceChipData(
        label: 'Referral',
        icon: Icons.group_add_rounded,
        color: Color(0xFFF59E0B),
      );
    }

    return _SourceChipData(
      label: raw,
      icon: Icons.label_rounded,
      color: const Color(0xFF64748B),
    );
  }

  int _pipelineDayNumber(dynamic client) {
    if (client is! Map) return 1;
    final c = client['created_at'];
    if (c == null) return 1;
    final dt = DateTime.tryParse(c.toString());
    if (dt == null) return 1;
    return DateTime.now().difference(dt).inDays + 1;
  }

  Future<void> _startAddFirstClient() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _privacyDialog(ctx),
    );
    if (proceed != true || !mounted) return;

    final choice = await _showAddMethodDialog();
    if (choice == null || !mounted) return;

    if (choice == 'manual') {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AddClientPage()),
      );

      if (created == true && mounted) {
        await _load();
      }
    } else if (choice == 'excel') {
      await _importExcelClients();
    }
  }

  Future<void> _importExcelClients() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel import is available in the mobile app.'),
        ),
      );
      return;
    }
    // Use FileType.any (not custom): some builds miss the native "custom" handler
    // until a full reinstall. Filter to .xlsx below.
    final FilePickerResult? pick;
    try {
      pick = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'File picker is not loaded. Fully stop the app, then run: '
            'flutter clean && flutter run '
            '(hot reload cannot register new native plugins).',
          ),
        ),
      );
      return;
    }
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.single;
    final path = f.path;
    final name = f.name;
    final isXlsx =
        name.toLowerCase().endsWith('.xlsx') ||
        (path != null && path.toLowerCase().endsWith('.xlsx'));
    if (!isXlsx) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Excel file (.xlsx).')),
      );
      return;
    }
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read the file path. Try saving the sheet locally first.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiClient.postMultipartFile(
      ApiEndpoints.clientsImportExcel,
      filePath: path,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final ok = res['success'] == true;
    final msg =
        res['message']?.toString() ??
        (ok ? 'Import complete' : 'Import failed');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
      ),
    );
    if (ok) await _load();
  }

  /// Copies the bundled Deal Room Excel template to a temp file and opens the share sheet
  /// so the user can save it to Files / Downloads / Drive.
  Future<void> _downloadDealRoomTemplate(BuildContext messengerContext) async {
    if (kIsWeb) {
      if (!messengerContext.mounted) return;
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        const SnackBar(
          content: Text('Template download is available in the mobile app.'),
        ),
      );
      return;
    }
    try {
      final data = await rootBundle.load(_dealRoomTemplateAsset);
      final bytes = data.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RealtorOne_Deal_Room_Clients_Template.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!messengerContext.mounted) return;
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: 'RealtorOne_Deal_Room_Clients_Template.xlsx',
          ),
        ],
        subject: 'RealtorOne — Deal Room import template',
        text: 'Fill this sheet, then tap Update Excel Sheet to import.',
      );
    } catch (e, st) {
      debugPrint('Template download failed: $e\n$st');
      if (!messengerContext.mounted) return;
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        SnackBar(
          content: Text('Could not open template: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<String?> _showAddMethodDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to add clients?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _methodOp(
                    icon: Icons.upload_file_rounded,
                    title: 'Update Excel Sheet',
                    subtitle:
                        'Use the same columns as our template, then upload',
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.pop(ctx, 'excel'),
                    isDark: isDark,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF059669),
                      ),
                      onPressed: () => _downloadDealRoomTemplate(context),
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text(
                        'Download sheet format',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _methodOp(
                icon: Icons.person_add_rounded,
                title: 'Add Manually',
                subtitle: 'Enter client details one by one',
                color: const Color(0xFF2563EB),
                onTap: () => Navigator.pop(ctx, 'manual'),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodOp({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _privacyDialog(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1220) : const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Privacy Matters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Client details entered here are\nstrictly confidential and used only\nfor your personal tracking. This data\nis not accessed, analyzed, or shared\nby the company.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'I Understand & Continue',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'END-TO-END ENCRYPTED ENVIRONMENT',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _hasClients ? _clientsList() : _intro();
  }

  Widget _intro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'The Deal Room',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Compact hero tile
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'THE DEAL ROOM',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startAddFirstClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text(
                'Add First Client',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _BottomMiniTab(
            icon: Icons.group_rounded,
            label: 'CLIENTS',
            active: true,
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _clientsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR CLIENTS',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: _sortByPriority
                      ? const Color(0xFF667EEA)
                      : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                ),
                tooltip: 'Sort by priority & progress',
                onPressed: _toggleSortByPriority,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._clients.take(6).toList().asMap().entries.map((entry) => _clientTile(entry.value, isDark)
              .animate()
              .fade(duration: 300.ms, delay: (50 * entry.key).ms)
              .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: (50 * entry.key).ms)),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _startAddFirstClient,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF667EEA),
                side: BorderSide(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                  width: 1.5,
                ),
                backgroundColor: const Color(
                  0xFF667EEA,
                ).withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Add New Prospect',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _clientTile(dynamic client, bool isDark) {
    final name = (client['client_name'] ?? 'Unnamed').toString();
    final status = (client['status'] ?? 'active').toString();

    // Priority for this client (1 = Normal, 2 = High, 3 = Urgent)
    int priority = 1;
    final notes = client['notes'];
    if (notes is String && notes.isNotEmpty) {
      try {
        final parsed = jsonDecode(notes);
        if (parsed is Map) {
          final dynamic rawPriority = parsed['priority_level'];
          if (rawPriority is num) {
            priority = rawPriority.toInt().clamp(1, 3);
          } else if (rawPriority is String) {
            final parsedInt = int.tryParse(rawPriority);
            if (parsedInt != null) {
              priority = parsedInt.clamp(1, 3);
            }
          }
        }
      } catch (_) {}
    }

    // Extract today's progress summary, if present
    final progress = client is Map
        ? client['today_progress'] as Map<String, dynamic>?
        : null;
    final int todayPercent = progress?['percentage'] is int
        ? progress!['percentage'] as int
        : (progress?['percentage'] is num
              ? (progress!['percentage'] as num).toInt()
              : 0);

    // Tile accent follows CRM pipeline stage (same vocabulary as Deal Room detail), not daily %.
    final String? rawStage = _readLeadStageRaw(client);
    late final Color mainColor;
    late final String mainLabel;

    if (status == 'lost') {
      mainColor = const Color(0xFFEF4444);
      mainLabel = 'Lost deal';
    } else {
      mainColor = _stageAccentColor(rawStage);
      mainLabel = _stageChipLabel(rawStage);
    }
    final sourceData = _sourceChipData(client is Map ? client['source'] : null);

    // Priority chip styling (shown near chevron)
    Color? priorityColor;
    String? priorityLabel;
    if (status != 'lost') {
      if (priority == 3) {
        priorityColor = const Color(0xFFF59E0B);
        priorityLabel = 'URGENT';
      } else if (priority == 2) {
        priorityColor = const Color(0xFF64748B);
        priorityLabel = 'HIGH';
      } else {
        priorityColor = null;
        priorityLabel = null;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final id = client['id'];
        if (id is int) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ClientRevenueActionsPage(clientId: id, clientName: name),
            ),
          ).then((_) async {
            widget.onClientActionLogged?.call();
            await _load();
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mainColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: mainColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // User Avatar Indicator
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: mainColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: mainColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: mainColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status == 'lost'
                        ? 'Not in active pipeline'
                        : 'Day ${_pipelineDayNumber(client)} · ${todayPercent.clamp(0, 100)}% of today\'s tasks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: mainColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'lost'
                                  ? Icons.block_rounded
                                  : Icons.signpost_rounded,
                              size: 12,
                              color: mainColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mainLabel.toUpperCase(),
                              style: TextStyle(
                                color: mainColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != 'lost')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sourceData.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: sourceData.color.withValues(alpha: 0.34),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sourceData.isFa
                                  ? FaIcon(
                                      sourceData.icon,
                                      size: 12,
                                      color: sourceData.color,
                                    )
                                  : Icon(
                                      sourceData.icon,
                                      size: 12,
                                      color: sourceData.color,
                                    ),
                              const SizedBox(width: 4),
                              Text(
                                sourceData.label,
                                style: TextStyle(
                                  color: sourceData.color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (priorityLabel != null && priorityColor != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(
                        alpha: isDark ? 0.25 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      priorityLabel,
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomMiniTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BottomMiniTab({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SourceChipData {
  final String label;
  final dynamic icon;
  final Color color;
  final bool isFa;

  const _SourceChipData({
    required this.label,
    required this.icon,
    required this.color,
    this.isFa = false,
  });
}
