import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class RevenueTrackerWidget extends StatefulWidget {
  const RevenueTrackerWidget({super.key});

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.revenueMetrics}?period=$_period',
        requiresAuth: true,
      );
      if (mounted && res['success'] == true) {
        final d = res['data'];
        setState(() {
          _hotLeads = d['hot_leads'] ?? 0;
          _dealsClosed = d['deals_closed'] ?? 0;
          _commission = (d['total_commission'] ?? 0).toDouble();
          _topSource = d['top_source'];
          _leadsChange = d['leads_change'] ?? 0;
          _dealsChange = d['deals_change'] ?? 0;
          _recentActivity = d['recent_activity'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Revenue metrics error: $e');
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                              )
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
                            : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
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
                  label: 'COMMISSION',
                  change: _commission > 0 ? 'Target Met' : '—',
                  changeColor: const Color(0xFF10B981),
                  isDark: isDark,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
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
            const SizedBox(height: 14),
            ...(_recentActivity.take(5).map((a) => _activityTile(a, isDark))),
          ],
        ],
      ],
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
  }) {
    return Container(
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
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
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
    );
  }

  Widget _activityTile(dynamic activity, bool isDark) {
    final type = activity['type'] ?? '';
    IconData icon;
    Color color;
    switch (type) {
      case 'hot_lead':
        icon = Icons.local_fire_department_rounded;
        color = const Color(0xFFF97316);
        break;
      case 'deal_closed':
        icon = Icons.celebration_rounded;
        color = const Color(0xFF22C55E);
        break;
      case 'commission':
        icon = Icons.monetization_on_rounded;
        color = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.circle;
        color = const Color(0xFF94A3B8);
    }

    return Container(
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
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (activity['value'] != null && activity['value'] > 0)
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
    );
  }
}
