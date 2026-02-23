import 'dart:convert';

import 'package:flutter/material.dart';
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

      final hasClients = statusRes['success'] == true &&
          (statusRes['has_clients'] == true || (statusRes['clients_count'] ?? 0) > 0);

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

  Future<void> _startAddFirstClient() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _privacyDialog(ctx),
    );
    if (proceed != true || !mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientPage()),
    );

    if (created == true && mounted) {
      await _load();
    }
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
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A8A),
                ],
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
    );
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
                'Clients',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: _sortByPriority
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                ),
                tooltip: 'Sort by priority & progress',
                onPressed: _toggleSortByPriority,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._clients.take(6).map((c) => _clientTile(c, isDark)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _startAddFirstClient,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: BorderSide(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Prospect',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
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
    final progress = client is Map ? client['today_progress'] as Map<String, dynamic>? : null;
    final int todayPercent = progress?['percentage'] is int
        ? progress!['percentage'] as int
        : (progress?['percentage'] is num ? (progress!['percentage'] as num).toInt() : 0);
    final String todayStatus = (progress?['status'] ?? 'none').toString();

    // Main color + label used for the left bar and subtitle
    late final Color mainColor;
    late final String mainLabel;

    if (status == 'lost') {
      // If client is lost, always show LOST even if priority is set
      mainColor = const Color(0xFFEF4444);
      mainLabel = 'LOST';
    } else if (todayStatus == 'high') {
      mainColor = const Color(0xFF16A34A); // strong green
      mainLabel = 'TODAY: ${todayPercent.clamp(0, 100)}% COMPLETE';
    } else if (todayStatus == 'medium') {
      mainColor = const Color(0xFFF59E0B); // amber
      mainLabel = 'TODAY: ${todayPercent.clamp(0, 100)}% COMPLETE';
    } else if (todayStatus == 'low') {
      mainColor = const Color(0xFFF97316); // orange
      mainLabel = 'TODAY: ${todayPercent.clamp(0, 100)}% COMPLETE';
    } else {
      // none / no actions yet
      mainColor = const Color(0xFFDC2626); // red
      mainLabel = 'TODAY: NOT STARTED';
    }

    // Priority chip styling (shown near chevron)
    Color? priorityColor;
    String? priorityLabel;
    if (status != 'lost') {
      if (priority == 3) {
        // Highest priority → GOLD
        priorityColor = const Color(0xFFFACC15); // gold
        priorityLabel = 'HIGH PRIORITY';
      } else if (priority == 2) {
        // Medium priority → SILVER
        priorityColor = const Color(0xFF9CA3AF); // silver / grey
        priorityLabel = 'LOW PRIORITY';
      } else {
        // Lowest / normal (1) → no chip
        priorityColor = null;
        priorityLabel = null;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final id = client['id'];
        if (id is int) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientRevenueActionsPage(
                clientId: id,
                clientName: name,
              ),
            ),
          ).then((_) async {
            widget.onClientActionLogged?.call();
            await _load(); // refresh clients + today progress after daily log actions
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 34,
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mainLabel,
                    style: TextStyle(
                      color: mainColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
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

