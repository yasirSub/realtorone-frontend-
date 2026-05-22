import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/user_api.dart';
import '../../widgets/elite_loader.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _period = 'week';
  bool _isLoading = true;
  List<String> _labels = [];
  List<int> _data = [];
  List<int> _executionData = [];
  int _growthScore = 0;
  int _executionRate = 0;

  // Real-world tactical icons for metrics
  final Map<String, IconData> _activityIcons = {
    'Calls': Icons.phone_in_talk_rounded,
    'Meetings': Icons.groups_rounded,
    'Follow-ups': Icons.repeat_rounded,
    'Site Visits': Icons.location_on_rounded,
  };

  Map<String, int> _activityBreakdown = {
    'Calls': 0,
    'Meetings': 0,
    'Follow-ups': 0,
    'Site Visits': 0,
  };
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await UserApi.getGrowthReport(_period);
      if (!mounted) return;

      if (response['success'] == true) {
        final labels = response['labels'];
        final data = response['data'];
        final execution = response['execution_data'] ?? response['points_data'];
        final breakdown = response['activity_breakdown'];

        setState(() {
          _labels = labels is List ? List<String>.from(labels.map((e) => e.toString())) : [];
          _data = data is List ? List<int>.from(data.map((e) => int.tryParse('$e') ?? 0)) : [];
          if (execution is List && execution.isNotEmpty) {
            _executionData = List<int>.from(execution.map((e) => int.tryParse('$e') ?? 0));
          } else {
            _executionData = _data
                .asMap()
                .entries
                .map((e) => (e.value * 0.85).round())
                .toList();
          }
          _growthScore = int.tryParse('${response['growth_score'] ?? 0}') ?? 0;
          _executionRate = int.tryParse('${response['execution_rate'] ?? 0}') ?? 0;
          if (breakdown is Map) {
            _activityBreakdown = breakdown.map(
              (key, value) => MapEntry(key.toString(), int.tryParse('$value') ?? 0),
            );
          }
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = response['message']?.toString() ?? 'Could not load performance report.';
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load performance report. Pull to refresh.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 20,
          ),
        ),
        title: Text(
          'Performance Reports',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: EliteLoader())
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: const Color(0xFF667eea),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    _buildPeriodTabs(isDark).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 24),

                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Growth Score',
                            '$_growthScore',
                            Icons.trending_up,
                            const Color(0xFF667eea),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Execution Rate',
                            '$_executionRate%',
                            Icons.bolt_rounded,
                            const Color(0xFF4ECDC4),
                            isDark,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    // Main Chart
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.1 : 0.03,
                            ),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Performance Analysis',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Row(
                                children: [
                                  _buildLegendItem(
                                    'Growth',
                                    const Color(0xFF667eea),
                                    isDark,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(
                                    'Execution',
                                    const Color(0xFF4ECDC4),
                                    isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 250,
                            child: LineChart(_buildChartData(isDark)),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    Text(
                      'Activity Breakdown',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 16),

                    _buildBreakdownList(
                      isDark,
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodTabs(bool isDark) {
    return Row(
      children: [
        _buildTab('Week', 'week', isDark),
        const SizedBox(width: 8),
        _buildTab('Month', 'month', isDark),
        const SizedBox(width: 8),
        _buildTab('Year', 'year', isDark),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, String value, bool isDark) {
    final isSelected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changePeriod(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF667eea)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF667eea)
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              width: 1.5,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(bool isDark) {
    return Column(
      children: _activityBreakdown.entries.map((entry) {
        final icon = _activityIcons[entry.key] ?? Icons.insights_rounded;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF667eea), size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.value > 0 ? 'Completed this period' : 'No activity yet',
                    style: TextStyle(
                      color: entry.value > 0
                          ? const Color(0xFF4ECDC4).withValues(alpha: 0.8)
                          : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'UNITS',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  double _chartMaxY() {
    final all = [..._data, ..._executionData];
    if (all.isEmpty) return 5;
    final peak = all.reduce((a, b) => a > b ? a : b);
    return (peak <= 0 ? 5 : peak + 2).toDouble();
  }

  LineChartData _buildChartData(bool isDark) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF1F5F9),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index >= 0 && index < _labels.length) {
                int skip = 1;
                if (_labels.length > 20) {
                  skip = 5;
                } else if (_labels.length > 10) {
                  skip = 2;
                }

                if (index % skip != 0) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _labels[index],
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              if (value % 1 == 0) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: isDark ? const Color(0xFF334155) : Colors.white,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((barSpot) {
              final flSpot = barSpot;
              return LineTooltipItem(
                '${flSpot.y.toInt()}',
                TextStyle(
                  color: barSpot.bar.color,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
      minX: 0,
      maxX: (_labels.isEmpty ? 0 : _labels.length - 1).toDouble(),
      minY: 0,
      maxY: _chartMaxY(),
      lineBarsData: [
        // Growth Line
        LineChartBarData(
          spots: _data.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value.toDouble());
          }).toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: const Color(0xFF667eea),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF667eea).withValues(alpha: 0.15),
                const Color(0xFF667eea).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // Execution Line (Improved: Solid, subtle neon glow, higher opacity)
        LineChartBarData(
          spots: _executionData.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value.toDouble());
          }).toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: const Color(0xFF4ECDC4),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 2,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF4ECDC4),
                ),
            checkToShowDot: (spot, barData) => spot.x.toInt() % 2 == 0,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                const Color(0xFF4ECDC4).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
