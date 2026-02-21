import 'dart:convert';

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import 'all_activities_page.dart';

class RevenueTrackerWidget extends StatefulWidget {
  final int? refreshTrigger;

  const RevenueTrackerWidget({super.key, this.refreshTrigger});

  @override
  State<RevenueTrackerWidget> createState() => _RevenueTrackerWidgetState();
}

class _RevenueTrackerWidgetState extends State<RevenueTrackerWidget> {
  String _period = 'month';
  bool _loading = true;
  int _hotLeads = 0;
  int _dealsClosed = 0;
  double _commission = 0;
  String? _topSource;
  int _leadsChange = 0;
  int _dealsChange = 0;
  List<dynamic> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RevenueTrackerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != null &&
        widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    debugPrint('[REVENUE_DEBUG] Fetching revenue metrics period=$_period');
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.revenueMetrics}?period=$_period',
        requiresAuth: true,
      );
      debugPrint('[REVENUE_DEBUG] API response: success=${res['success']}');
      if (mounted && res['success'] == true) {
        final d = res['data'];
        final activities = d['recent_activity'] ?? [];
        debugPrint('[REVENUE_DEBUG] recent_activity count=${activities.length}');
        for (var i = 0; i < activities.length && i < 5; i++) {
          final a = activities[i];
          debugPrint('[REVENUE_DEBUG]   [$i] type=${a['type']} client=${a['client_name']}');
        }
        if (activities.length > 5) {
          debugPrint('[REVENUE_DEBUG]   ... and ${activities.length - 5} more');
        }
        setState(() {
          _hotLeads = d['hot_leads'] ?? 0;
          _dealsClosed = d['deals_closed'] ?? 0;
          _commission = (d['total_commission'] ?? 0).toDouble();
          _topSource = d['top_source'];
          _leadsChange = d['leads_change'] ?? 0;
          _dealsChange = d['deals_change'] ?? 0;
          _recentActivity = activities;
        });
      } else {
        debugPrint('[REVENUE_DEBUG] Unexpected or failed response: success=${res['success']}');
      }
    } catch (e, st) {
      debugPrint('[REVENUE_DEBUG] ERROR: $e');
      debugPrint('[REVENUE_DEBUG] Stack: $st');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatCommission(double v) {
    if (v >= 1000000) return 'AED ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'AED ${(v / 1000).toStringAsFixed(0)}k';
    return 'AED ${v.toStringAsFixed(0)}';
  }

  String _changeLabel(int pct) {
    if (pct > 0) return '+$pct%';
    if (pct < 0) return '$pct%';
    return 'Stable';
  }

  Color _changeColor(int pct) {
    if (pct > 0) return const Color(0xFF10B981);
    if (pct < 0) return const Color(0xFFEF4444);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period toggle
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['week', 'month', 'quarter'].map((p) {
                final active = _period == p;
                return GestureDetector(
                  onTap: () {
                    if (_period != p) {
                      _period = p;
                      _load();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark ? Colors.white : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      p[0].toUpperCase() + p.substring(1),
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                        color: active
                            ? const Color(0xFF2563EB)
                            : (isDark
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Performance Overview label
        Center(
          child: Text(
            'PERFORMANCE OVERVIEW',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.5,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Key Metrics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),

        const SizedBox(height: 20),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Top 2 metric cards
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  icon: Icons.local_fire_department_rounded,
                  iconBg: const Color(0xFFFED7AA),
                  iconColor: const Color(0xFFF97316),
                  value: '$_hotLeads',
                  label: 'HOT LEADS',
                  change: _changeLabel(_leadsChange),
                  changeColor: _changeColor(_leadsChange),
                  isDark: isDark,
                  onTap: () => _showMetricDetail(context, 'hot_leads', isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  icon: Icons.rocket_launch_rounded,
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  value: '$_dealsClosed',
                  label: 'DEALS CLOSED',
                  change: _changeLabel(_dealsChange),
                  changeColor: _changeColor(_dealsChange),
                  isDark: isDark,
                  onTap: () => _showMetricDetail(context, 'deals_closed', isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom 2 metric cards
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  icon: Icons.monetization_on_rounded,
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF10B981),
                  value: _formatCommission(_commission),
                  label: 'NET COMMISSION EARNED',
                  change: _commission > 0 ? 'Target Met' : '—',
                  changeColor: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => _showMetricDetail(context, 'commission', isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  icon: Icons.trending_up_rounded,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF8B5CF6),
                  value: _topSource != null
                      ? _topSource![0].toUpperCase() +
                            _topSource!.substring(1).replaceAll('_', ' ')
                      : '—',
                  label: 'TOP SOURCE',
                  change: _topSource != null ? 'Organic' : '—',
                  changeColor: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  onTap: () => _showMetricDetail(context, 'top_source', isDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Recent Activity
          if (_recentActivity.isNotEmpty) ...[
            const Center(
              child: Text(
                'Recent Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllActivitiesPage(),
                    ),
                  );
                },
                child: Text(
                  'VIEW ALL ACTIVITIES',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1,
                    color: isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...(_recentActivity.take(5).map((a) => _activityTile(a, isDark))),
          ],
        ],
      ],
    );
  }

  void _showMetricDetail(BuildContext context, String metricType, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MetricDetailSheet(
        metricType: metricType,
        topSource: _topSource,
        isDark: isDark,
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
    required String change,
    required Color changeColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            change,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: changeColor,
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _getActionLabel(dynamic activity) {
    try {
      final notes = activity['notes'];
      if (notes is String && notes.isNotEmpty) {
        final map = jsonDecode(notes) as Map<String, dynamic>?;
        final label = map?['action_label']?.toString();
        if (label != null && label.isNotEmpty) return label.toUpperCase();
      }
    } catch (_) {}
    return 'REVENUE ACTION';
  }

  Widget _activityTile(dynamic activity, bool isDark) {
    final type = activity['type'] ?? '';
    IconData icon;
    Color color;
    String subtitle;
    switch (type) {
      case 'hot_lead':
        icon = Icons.local_fire_department_rounded;
        color = const Color(0xFFF97316);
        subtitle = 'HOT LEAD';
        break;
      case 'deal_closed':
        icon = Icons.celebration_rounded;
        color = const Color(0xFF22C55E);
        subtitle = 'DEAL CLOSED';
        break;
      case 'commission':
        icon = Icons.monetization_on_rounded;
        color = const Color(0xFF10B981);
        subtitle = 'COMMISSION';
        break;
      case 'revenue_action':
        icon = Icons.task_alt_rounded;
        color = const Color(0xFF6366F1);
        subtitle = _getActionLabel(activity);
        break;
      default:
        icon = Icons.circle;
        color = const Color(0xFF94A3B8);
        subtitle = type.toString().replaceAll('_', ' ').toUpperCase();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllActivitiesPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['client_name'] ?? type.replaceAll('_', ' '),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if ((double.tryParse(activity['value']?.toString() ?? '0') ?? 0) >
                0)
              Text(
                'AED ${activity['value']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFF10B981),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricDetailSheet extends StatefulWidget {
  final String metricType;
  final String? topSource;
  final bool isDark;

  const _MetricDetailSheet({
    required this.metricType,
    this.topSource,
    required this.isDark,
  });

  @override
  State<_MetricDetailSheet> createState() => _MetricDetailSheetState();
}

class _MetricDetailSheetState extends State<_MetricDetailSheet> {
  bool _loading = true;
  List<dynamic> _items = [];
  String _title = '';
  String _emptyMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String url = '${ApiEndpoints.results}?type=';
      if (widget.metricType == 'hot_leads') {
        url += 'hot_lead';
        _title = 'Clients';
        _emptyMsg = 'No clients yet';
      } else if (widget.metricType == 'deals_closed') {
        url += 'deal_closed';
        _title = 'Deals Closed';
        _emptyMsg = 'No deals closed yet';
      } else if (widget.metricType == 'commission') {
        url += 'deal_closed';
        _title = 'Commission by Client';
        _emptyMsg = 'No commission earned yet';
      } else if (widget.metricType == 'top_source' &&
          widget.topSource != null &&
          widget.topSource!.isNotEmpty) {
        url += 'hot_lead&source=${Uri.encodeComponent(widget.topSource!)}';
        _title = 'Clients from ${widget.topSource!.replaceAll('_', ' ')}';
        _emptyMsg = 'No clients from this source';
      } else {
        _title = 'Details';
        _emptyMsg = 'No data';
        setState(() {
          _loading = false;
          _items = [];
        });
        return;
      }

      final res = await ApiClient.get(url, requiresAuth: true);
      if (mounted && res['success'] == true) {
        setState(() {
          _items = res['data'] ?? [];
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCommission(double v) {
    if (v >= 1000000) return 'AED ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'AED ${(v / 1000).toStringAsFixed(0)}k';
    return 'AED ${v.toStringAsFixed(0)}';
  }

  double _getCommission(dynamic item) {
    try {
      final notes = item['notes'];
      if (notes is String && notes.isNotEmpty) {
        final map = jsonDecode(notes) as Map<String, dynamic>?;
        return (double.tryParse(map?['commission']?.toString() ?? '0') ?? 0);
      }
    } catch (_) {}
    return 0;
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.tryParse(d.toString());
      if (dt != null) {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _emptyMsg,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          final clientName =
                              item['client_name']?.toString() ?? 'Unknown';
                          final source = item['source']?.toString();
                          if (widget.metricType == 'hot_leads') {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF97316)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFFF97316),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          clientName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                        if (source != null &&
                                            source.isNotEmpty)
                                          Text(
                                            source.replaceAll('_', ' '),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (widget.metricType == 'deals_closed') {
                            final value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.celebration_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          clientName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          _formatDate(item['date']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (value > 0)
                                    Text(
                                      _formatCommission(value),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          } else if (widget.metricType == 'commission') {
                            final commission = _getCommission(item);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.monetization_on_rounded,
                                      color: Color(0xFF10B981),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      clientName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  if (commission > 0)
                                    Text(
                                      _formatCommission(commission),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          } else {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFF8B5CF6),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      clientName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
