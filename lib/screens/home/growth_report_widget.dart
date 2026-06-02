import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api/user_api.dart';
import '../../l10n/app_localizations.dart';
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
  int _growthDeltaPercent = 0;
  List<double> _chartErValues = [];

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
        final executionData = response['execution_data'];
        final chartValues = <double>[];
        if (executionData is List) {
          for (final item in executionData) {
            final parsed = double.tryParse('$item') ?? 0;
            chartValues.add(parsed > 1 ? parsed / 100 : parsed);
          }
        }

        setState(() {
          _growthScore = int.tryParse(
                '${response['growth_potential'] ?? response['growth_score'] ?? 0}',
              ) ??
              0;
          _executionRate =
              int.tryParse('${response['execution_rate'] ?? 0}') ?? 0;
          _growthDeltaPercent =
              int.tryParse('${response['growth_delta_percent'] ?? 0}') ?? 0;
          _chartErValues = chartValues;
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _deltaLabel() {
    final sign = _growthDeltaPercent >= 0 ? '+' : '';
    return '$sign$_growthDeltaPercent%';
  }

  List<FlSpot> _chartSpots(Color color) {
    if (_chartErValues.isEmpty) {
      return const [
        FlSpot(0, 0.2),
        FlSpot(1, 0.35),
        FlSpot(2, 0.3),
        FlSpot(3, 0.5),
        FlSpot(4, 0.45),
        FlSpot(5, 0.6),
        FlSpot(6, 0.55),
      ];
    }
    return List.generate(
      _chartErValues.length,
      (i) => FlSpot(i.toDouble(), _chartErValues[i].clamp(0.0, 1.0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 120, child: Center(child: EliteLoader()));
    }

    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              l10n.growthPotential,
              '$_growthScore',
              const Color(0xFF667eea),
              Icons.trending_up_rounded,
              true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricCard(
              l10n.executionRate,
              '$_executionRate%',
              const Color(0xFF4ECDC4),
              Icons.bolt_rounded,
              false,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
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
    final delta = isGrowth ? _deltaLabel() : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              if (delta != null)
                Text(
                  delta,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -1,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 24,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots(color),
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
