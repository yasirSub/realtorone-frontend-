import 'dart:convert';

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class AllActivitiesPage extends StatefulWidget {
  const AllActivitiesPage({super.key});

  @override
  State<AllActivitiesPage> createState() => _AllActivitiesPageState();
}

class _AllActivitiesPageState extends State<AllActivitiesPage> {
  bool _loading = true;
  List<dynamic> _activities = [];
  List<dynamic> _clients = [];
  String? _filterClientName; // null = All

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.results}?type=hot_lead',
        requiresAuth: true,
      );
      if (mounted && res['success'] == true) {
        setState(() {
          _clients = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading clients: $e');
    }
  }

  List<dynamic> get _filteredActivities {
    if (_filterClientName == null || _filterClientName!.isEmpty) {
      return _activities;
    }
    return _activities
        .where((a) =>
            (a['client_name'] ?? '').toString() == _filterClientName)
        .toList();
  }

  Future<void> _loadActivities() async {
    setState(() => _loading = true);
    debugPrint('[ALL_ACTIVITIES_DEBUG] Fetching recent_activity (period=month)');
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.revenueMetrics}?period=month',
        requiresAuth: true,
      );
      debugPrint('[ALL_ACTIVITIES_DEBUG] API success=${res['success']}');
      if (mounted && res['success'] == true) {
        final activities = res['data']['recent_activity'] ?? [];
        debugPrint('[ALL_ACTIVITIES_DEBUG] Loaded ${activities.length} activities');
        setState(() {
          _activities = activities;
        });
      }
    } catch (e, st) {
      debugPrint('[ALL_ACTIVITIES_DEBUG] ERROR: $e');
      debugPrint('[ALL_ACTIVITIES_DEBUG] Stack: $st');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showFilterSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Text(
                      'Filter by client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _filterSheetItem(
                      label: 'All activities',
                      selected: _filterClientName == null,
                      isDark: isDark,
                      onTap: () {
                        setState(() => _filterClientName = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ..._clients.map((c) {
                      final name = c['client_name']?.toString() ?? 'Unknown';
                      return _filterSheetItem(
                        label: name,
                        selected: _filterClientName == name,
                        isDark: isDark,
                        onTap: () {
                          setState(() => _filterClientName = name);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterSheetItem({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 22,
        color: selected
            ? const Color(0xFF2563EB)
            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
      onTap: onTap,
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} mins ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  String _getActionLabelFromNotes(dynamic activity) {
    try {
      final notes = activity['notes'];
      if (notes is String && notes.isNotEmpty) {
        final map = jsonDecode(notes) as Map<String, dynamic>?;
        final label = map?['action_label']?.toString();
        if (label != null && label.isNotEmpty) return label;
      }
    } catch (_) {}
    return 'Daily action completed';
  }

  String _getStatusLabel(String type) {
    switch (type) {
      case 'hot_lead':
        return 'Interested';
      case 'deal_closed':
        return 'Deal Closed';
      case 'commission':
        return 'Completed';
      case 'revenue_action':
        return 'Completed';
      default:
        return 'In Progress';
    }
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'hot_lead':
        return const Color(0xFF3B82F6); // Light blue
      case 'deal_closed':
        return const Color(0xFFF97316); // Light orange
      case 'commission':
        return const Color(0xFF10B981); // Light green
      case 'revenue_action':
        return const Color(0xFF6366F1); // Indigo
      default:
        return const Color(0xFF94A3B8); // Light gray
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'hot_lead':
        return Icons.local_fire_department_rounded;
      case 'deal_closed':
        return Icons.celebration_rounded;
      case 'commission':
        return Icons.monetization_on_rounded;
      case 'revenue_action':
        return Icons.task_alt_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityIconColor(String type) {
    switch (type) {
      case 'hot_lead':
        return const Color(0xFF3B82F6);
      case 'deal_closed':
        return const Color(0xFF10B981);
      case 'commission':
        return const Color(0xFFF97316);
      case 'revenue_action':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getActivityDescription(dynamic activity, String type) {
    switch (type) {
      case 'hot_lead':
        return 'Initial outreach via phone';
      case 'deal_closed':
        return 'Deal successfully closed';
      case 'commission':
        return 'Commission received';
      case 'revenue_action':
        return _getActionLabelFromNotes(activity);
      default:
        return 'Activity completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Activities',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your journey in motion',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Client filter - compact button
            if (_clients.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () => _showFilterSheet(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filterClientName != null
                            ? const Color(0xFF2563EB).withValues(alpha: 0.5)
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: _filterClientName != null
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _filterClientName ?? 'All activities',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Activities List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadActivities();
                  await _loadClients();
                },
                color: const Color(0xFF2563EB),
                child: _loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : _filteredActivities.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inbox_rounded,
                                        size: 64,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No activities yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          itemCount: _filteredActivities.length,
                          itemBuilder: (context, index) {
                            final activity = _filteredActivities[index];
                            final type = activity['type'] ?? '';
                            final clientName =
                                activity['client_name'] ?? 'Unknown';
                            final timestamp = activity['created_at'] ??
                                activity['timestamp'] ??
                                activity['date'];
                            final value = activity['value'];

                            return _buildActivityItem(
                              activity,
                              type,
                              clientName,
                              timestamp,
                              value,
                              isDark,
                              index == _filteredActivities.length - 1,
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    dynamic activity,
    String type,
    String clientName,
    dynamic timestamp,
    dynamic value,
    bool isDark,
    bool isLast,
  ) {
    final icon = _getActivityIcon(type);
    final iconColor = _getActivityIconColor(type);
    final statusLabel = _getStatusLabel(type);
    final statusColor = _getStatusColor(type);
    final description = _getActivityDescription(activity, type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line and icon
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Activity content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white60
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                // Status tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Timestamp
        Text(
          _formatTimestamp(timestamp?.toString()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
