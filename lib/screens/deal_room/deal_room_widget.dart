import 'dart:convert';
import 'dart:io';
import 'dart:ui';

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
import '../../theme/realtorone_brand.dart';
import 'add_client_page.dart';
import 'client_revenue_actions_page.dart';

enum _DealRoomListFilter {
  all,
  notAttemptedFour,
  nurture,
  other,
}

class DealRoomWidget extends StatefulWidget {
  final VoidCallback? onClientActionLogged;
  final String? initialSelectedStage;

  const DealRoomWidget({
    super.key,
    this.onClientActionLogged,
    this.initialSelectedStage,
  });

  @override
  State<DealRoomWidget> createState() => _DealRoomWidgetState();

  static Map<String, int> getStageCounts(List<dynamic> clients) {
    final counts = <String, int>{};
    for (final c in clients) {
      if (c is Map && c['status'] == 'lost') continue;
      final raw = readLeadStageRaw(c);
      final label = stageChipLabel(raw);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  static String? readLeadStageRaw(dynamic client) {
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

  static String stageChipLabel(String? raw) {
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

  static Future<String?> showCrmStagePicker({
    required BuildContext context,
    String? currentStage,
    Map<String, int>? counts,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stages = [
      'Cold calling',
      'Follow-up',
      'Client meeting',
      'Deal negotiation',
      'Deal closure',
    ];

    // Stage config: icon, color per stage
    const stageConfig = <String, Map<String, dynamic>>{
      'Cold calling':     {'icon': Icons.phone_rounded,        'color': Color(0xFF2563EB)},
      'Follow-up':        {'icon': Icons.refresh_rounded,       'color': Color(0xFF0D9488)},
      'Client meeting':   {'icon': Icons.people_rounded,        'color': Color(0xFF7C3AED)},
      'Deal negotiation': {'icon': Icons.handshake_rounded,     'color': Color(0xFFEA580C)},
      'Deal closure':     {'icon': Icons.verified_rounded,      'color': Color(0xFF16A34A)},
    };

    final totalClients = counts?.values.fold(0, (a, b) => a + b) ?? 0;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? selected = currentStage;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // "All Stages" option
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setModal(() => selected = null);
                        Future.delayed(const Duration(milliseconds: 150), () => Navigator.pop(ctx, null));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected == null
                              ? const Color(0xFF667EEA).withValues(alpha: 0.1)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected == null ? const Color(0xFF667EEA).withValues(alpha: 0.5) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            width: selected == null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667EEA).withValues(alpha: selected == null ? 0.15 : 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.all_inclusive_rounded, size: 18, color: const Color(0xFF667EEA).withValues(alpha: selected == null ? 1 : 0.5)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text('All Stages',
                                style: TextStyle(
                                  fontWeight: selected == null ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 15,
                                  color: selected == null ? const Color(0xFF667EEA) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$totalClients', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF667EEA))),
                            ),
                            if (selected == null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF667EEA)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stage list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: stages.map((s) {
                        final count = counts?[s] ?? 0;
                        final isSelected = selected == s;
                        final cfg = stageConfig[s]!;
                        final stageColor = cfg['color'] as Color;
                        final stageIcon = cfg['icon'] as IconData;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setModal(() => selected = s);
                              Future.delayed(const Duration(milliseconds: 150), () => Navigator.pop(ctx, s));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? stageColor.withValues(alpha: 0.08)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? stageColor.withValues(alpha: 0.4) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: isSelected ? [BoxShadow(color: stageColor.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))] : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: stageColor.withValues(alpha: isSelected ? 0.15 : 0.07),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(stageIcon, size: 17, color: stageColor.withValues(alpha: isSelected ? 1 : 0.6)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(s,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                        fontSize: 14.5,
                                        color: isSelected ? stageColor : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: stageColor.withValues(alpha: isSelected ? 0.15 : 0.07),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$count',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: stageColor.withValues(alpha: isSelected ? 1 : 0.7),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check_circle_rounded, size: 20, color: stageColor),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 16 + MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DealRoomWidgetState extends State<DealRoomWidget> {
  static const String _dealRoomTemplateAsset =
      'assets/templates/deal_room_clients_template.xlsx';

  bool _isLoading = true;
  bool _hasClients = true;
  List<dynamic> _clients = [];
  List<dynamic> _originalClients = [];
  bool _sortByPriority = false;
  _DealRoomListFilter _listFilter = _DealRoomListFilter.all;
  String? _selectedCrmStage;

  @override
  void didUpdateWidget(DealRoomWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedStage != oldWidget.initialSelectedStage &&
        widget.initialSelectedStage != null) {
      setState(() => _selectedCrmStage = widget.initialSelectedStage);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedCrmStage = widget.initialSelectedStage;
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
      final int byToday = db.compareTo(da);
      if (byToday != 0) return byToday;

      final nameA = (a is Map ? (a['client_name'] ?? '') : '').toString().toLowerCase();
      final nameB = (b is Map ? (b['client_name'] ?? '') : '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    _clients = sorted;
  }

  String _filterLabel(_DealRoomListFilter f) {
    switch (f) {
      case _DealRoomListFilter.all:
        return 'All shortlists';
      case _DealRoomListFilter.notAttemptedFour:
        return 'Not attempted 4×';
      case _DealRoomListFilter.nurture:
        return 'Nurture list only';
      case _DealRoomListFilter.other:
        return 'Other pipeline only';
    }
  }

  void _showListOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var filter = _listFilter;
    var sort = _sortByPriority;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(ctx).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Clients view',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick a shortlist to focus on. Sort applies within that list.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._DealRoomListFilter.values.map(
                    (f) => RadioListTile<_DealRoomListFilter>(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      value: f,
                      groupValue: filter,
                      activeColor: const Color(0xFF667EEA),
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => filter = v);
                      },
                      title: Text(
                        _filterLabel(f),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sort,
                    activeColor: const Color(0xFF667EEA),
                    title: Text(
                      'Sort by priority',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      'Urgent first, then today’s task %, then name',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                    onChanged: (v) => setModal(() => sort = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _listFilter = filter;
                          _sortByPriority = sort;
                          _applySort();
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCrmStagePicker() async {
    final counts = DealRoomWidget.getStageCounts(_originalClients);
    final result = await DealRoomWidget.showCrmStagePicker(
      context: context,
      currentStage: _selectedCrmStage,
      counts: counts,
    );
    if (mounted) {
      setState(() => _selectedCrmStage = result);
    }
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



  Color _stageAccentColor(String? raw) {
    if (raw == null || raw.isEmpty) return const Color(0xFF2563EB);
    final t = raw.toLowerCase();
    if (t.contains('cold')) return const Color(0xFF2563EB);
    if (t.contains('follow')) return const Color(0xFF0D9488);
    if (t.contains('client meeting') || t.contains('clint')) {
      return const Color(0xFF7C3AED);
    }
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

  Map<String, dynamic>? _notesMap(dynamic client) {
    if (client is! Map) return null;
    final notes = client['notes'];
    if (notes is! String || notes.trim().isEmpty) return null;
    try {
      final parsed = jsonDecode(notes);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  int _maxAttemptCountFromNotes(dynamic client) {
    final map = _notesMap(client);
    if (map == null) return 0;
    final cc = map['cold_calling'];
    if (cc is! Map) return 0;

    final callA = int.tryParse((cc['call_attempt'] ?? '0').toString()) ?? 0;
    final waA = int.tryParse((cc['wa_attempt'] ?? '0').toString()) ?? 0;
    return callA > waA ? callA : waA;
  }

  bool _isNurtureClient(dynamic client) {
    final map = _notesMap(client);
    if (map == null) return false;

    final pkg = (map['lead_package'] ?? '').toString().toLowerCase().trim();
    if (pkg == 'nurture') return true;

    final stageRaw = (map['lead_stage'] ?? '').toString().toLowerCase();
    if (stageRaw.contains('nurture') ||
        stageRaw.contains('retarget') ||
        stageRaw.contains('stall')) {
      return true;
    }

    bool stageIsNurture(dynamic stage) {
      if (stage is! Map) return false;
      final bucket = (stage['bucket'] ?? '').toString().toLowerCase();
      return bucket == 'nurture_whatsapp' ||
          bucket == 'retargeting' ||
          bucket == 'stalled' ||
          bucket == 'nutshell';
    }

    return stageIsNurture(map['cold_calling']) ||
        stageIsNurture(map['follow_up']) ||
        stageIsNurture(map['client_meeting']) ||
        stageIsNurture(map['deal_negotiation']) ||
        stageIsNurture(map['deal_closure']);
  }

  Widget _groupSection({
    required String title,
    required String subtitle,
    required List<dynamic> items,
    required bool isDark,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((c) => _clientTile(c, isDark)),
      ],
    );
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12 + bottomInset,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xEE0F172A),
                            const Color(0xEE1E293B),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.97),
                            const Color(0xFFF8FAFC),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.12,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Add clients',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick how you want to load your Deal Room — bulk import or one-by-one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _methodOp(
                        icon: Icons.table_chart_rounded,
                        title: 'Import from Excel',
                        subtitle:
                            'Match our template columns, then upload your .xlsx file.',
                        accent: RealtorOneBrand.accentTeal,
                        onTap: () => Navigator.pop(ctx, 'excel'),
                        isDark: isDark,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                _downloadDealRoomTemplate(ctx),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                    color: RealtorOneBrand.accentTeal,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Download template (.xlsx)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: RealtorOneBrand.accentTeal,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _methodOp(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Add manually',
                        subtitle:
                            'Enter name, contact, and notes in a guided form.',
                        accent: RealtorOneBrand.accentIndigo,
                        onTap: () => Navigator.pop(ctx, 'manual'),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.45)
                                : const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _methodOp({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final titleColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? Colors.white54 : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: isDark ? 0.09 : 0.07),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, Color.lerp(accent, Colors.black, 0.15)!],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent.withValues(alpha: 0.85),
                  size: 26,
                ),
              ],
            ),
          ),
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

    var filtered = _clients;
    if (_selectedCrmStage != null) {
      filtered = filtered.where((c) {
        final raw = DealRoomWidget.readLeadStageRaw(c);
        return DealRoomWidget.stageChipLabel(raw) == _selectedCrmStage;
      }).toList();
    }
    final visibleClients = filtered.take(12).toList();

    final notAttemptedFourTimes = visibleClients
        .where((c) => _maxAttemptCountFromNotes(c) >= 4)
        .toList();
    final nurtureClients = visibleClients.where(_isNurtureClient).toList();
    final otherClients = visibleClients
        .where(
          (c) =>
              !notAttemptedFourTimes.contains(c) && !nurtureClients.contains(c),
        )
        .toList();

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
              const Spacer(),
              Tooltip(
                message: 'Filter by CRM stage',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showCrmStagePicker,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.account_tree_rounded,
                        size: 22,
                        color: _selectedCrmStage != null
                            ? const Color(0xFF667EEA)
                            : (isDark
                                ? Colors.white54
                                : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Filter shortlist & sort',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showListOptionsSheet,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.filter_list_rounded,
                        size: 22,
                        color: (_listFilter != _DealRoomListFilter.all ||
                                _sortByPriority)
                            ? const Color(0xFF667EEA)
                            : (isDark
                                ? Colors.white54
                                : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_listFilter == _DealRoomListFilter.all ||
              _listFilter == _DealRoomListFilter.notAttemptedFour)
            _groupSection(
              title: 'NOT ATTEMPTED 4 TIMES',
              subtitle: 'Clients with 4+ unanswered cold touch attempts',
              items: notAttemptedFourTimes,
              isDark: isDark,
            ),
          if (_listFilter == _DealRoomListFilter.all ||
              _listFilter == _DealRoomListFilter.nurture)
            _groupSection(
              title: 'NURTURE LIST',
              subtitle: 'Stalled / retargeting / nurture-stage clients',
              items: nurtureClients,
              isDark: isDark,
            ),
          if (_listFilter == _DealRoomListFilter.all ||
              _listFilter == _DealRoomListFilter.other)
            _groupSection(
              title: 'OTHER CLIENTS',
              subtitle: 'All remaining active clients in your pipeline',
              items: otherClients,
              isDark: isDark,
            ),
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
    final String? rawStage = DealRoomWidget.readLeadStageRaw(client);
    late final Color mainColor;
    late final String mainLabel;

    if (status == 'lost') {
      mainColor = const Color(0xFFEF4444);
      mainLabel = 'Lost deal';
    } else {
      mainColor = _stageAccentColor(rawStage);
      mainLabel = DealRoomWidget.stageChipLabel(rawStage);
    }
    final sourceData = _sourceChipData(
      client is Map ? client['source'] : null,
    );
    final isNurture = _isNurtureClient(client);
    const nurtureChipColor = Color(0xFF059669);

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
                      if (status != 'lost' && isNurture)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: nurtureChipColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: nurtureChipColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_rounded,
                                size: 12,
                                color: nurtureChipColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'NURTURE',
                                style: TextStyle(
                                  color: nurtureChipColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  letterSpacing: 0.35,
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
