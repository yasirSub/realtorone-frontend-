import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api/user_api.dart';
import '../../widgets/elite_loader.dart';
import '../../routes/app_routes.dart';

class GrowthReportWidget extends StatefulWidget {
  const GrowthReportWidget({super.key});

  @override
  State<GrowthReportWidget> createState() => _GrowthReportWidgetState();
}

class _GrowthReportWidgetState extends State<GrowthReportWidget> {
  bool _isLoading = true;
  int _growthScore = 0;
  int _executionRate = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await UserApi.getGrowthReport('week');
      if (mounted && response['success'] == true) {
        setState(() {
          _growthScore = response['growth_score'];
          _executionRate = response['execution_rate'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const SizedBox(height: 120, child: Center(child: EliteLoader()));
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Growth Potential',
                  '$_growthScore',
                  const Color(0xFF667eea),
                  Icons.trending_up_rounded,
                  true, // isGrowth
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Execution Rate',
                  '$_executionRate%',
                  const Color(0xFF4ECDC4),
                  Icons.bolt_rounded,
                  false, // isExecution
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // SECONDARY HUD: ACTIVITY PULSE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPulseItem(
                  Icons.phone_in_talk_rounded,
                  'CALLS',
                  '45',
                  isDark,
                ),
                _buildPulseItem(Icons.groups_rounded, 'MEET', '12', isDark),
                _buildPulseItem(Icons.repeat_rounded, 'FOLD', '28', isDark),
                _buildPulseItem(
                  Icons.location_on_rounded,
                  'SITE',
                  '08',
                  isDark,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
        ],
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildPulseItem(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: isDark ? Colors.white38 : const Color(0xFF64748B),
          size: 14,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF64748B),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    IconData icon,
    bool isGrowth,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                '+12%',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -1,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: isGrowth
                        ? const [
                            FlSpot(0, 1),
                            FlSpot(1, 1.5),
                            FlSpot(2, 1.2),
                            FlSpot(3, 2),
                            FlSpot(4, 1.8),
                            FlSpot(5, 2.5),
                          ]
                        : const [
                            FlSpot(0, 2),
                            FlSpot(1, 1.8),
                            FlSpot(2, 2.2),
                            FlSpot(3, 1.5),
                            FlSpot(4, 2.1),
                            FlSpot(5, 1.9),
                          ],
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
