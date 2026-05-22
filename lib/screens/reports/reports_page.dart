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

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  String _period = 'week';
  bool _isLoading = true;
  List<String> _labels = [];
  List<int> _data = [];
  int _growthScore = 0;
  int _executionRate = 0;
  int _beliefScore = 0;
  int _focusScore = 0;
  int _beliefTasksDone = 0;
  int _beliefTasksTotal = 0;
  double _beliefPointsPerTask = 11.1;
  double _beliefErContribution = 0;
  double _beliefGpContribution = 0;
  double _focusErContribution = 0;
  double _focusGpContribution = 0;
  int _focusClientCount = 0;

  List<Map<String, dynamic>> _beliefBreakdown = [];
  List<Map<String, dynamic>> _focusBreakdown = [];
  List<Map<String, dynamic>> _focusPipeline = [];

  final Map<String, IconData> _focusActivityIcons = {
    'Calls': Icons.phone_in_talk_rounded,
    'Meetings': Icons.groups_rounded,
    'Follow-ups': Icons.repeat_rounded,
    'Site Visits': Icons.location_on_rounded,
  };

  late TabController _pillarTabController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pillarTabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _pillarTabController.dispose();
    super.dispose();
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
        setState(() {
          _labels = labels is List ? List<String>.from(labels.map((e) => e.toString())) : [];
          _data = data is List ? List<int>.from(data.map((e) => int.tryParse('$e') ?? 0)) : [];
          _growthScore = int.tryParse(
                '${response['growth_potential'] ?? response['growth_score'] ?? 0}',
              ) ??
              0;
          _executionRate = int.tryParse('${response['execution_rate'] ?? 0}') ?? 0;
          _beliefScore = int.tryParse('${response['belief_score'] ?? 0}') ?? 0;
          _focusScore = int.tryParse('${response['focus_score'] ?? 0}') ?? 0;
          _beliefTasksDone = int.tryParse('${response['belief_tasks_done'] ?? 0}') ?? 0;
          _beliefTasksTotal = int.tryParse('${response['belief_tasks_total'] ?? 0}') ?? 0;
          _beliefPointsPerTask =
              double.tryParse('${response['belief_points_per_task'] ?? 11.1}') ?? 11.1;
          _beliefErContribution =
              double.tryParse('${response['belief_er_contribution'] ?? 0}') ?? 0;
          _beliefGpContribution =
              double.tryParse('${response['belief_gp_contribution'] ?? 0}') ?? 0;
          _focusErContribution =
              double.tryParse('${response['focus_er_contribution'] ?? 0}') ?? 0;
          _focusGpContribution =
              double.tryParse('${response['focus_gp_contribution'] ?? 0}') ?? 0;
          _focusClientCount = int.tryParse(
                '${(response['focus_pillar'] as Map?)?['client_count'] ?? 0}',
              ) ??
              0;
          _beliefBreakdown = _parseListMap(response['belief_breakdown']);
          _focusBreakdown = _parseListMap(response['focus_breakdown']);
          _focusPipeline = _parseListMap(response['focus_pipeline']);
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

  List<Map<String, dynamic>> _parseListMap(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
                            'Growth Potential',
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

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Belief',
                            '$_beliefScore%',
                            Icons.self_improvement_rounded,
                            const Color(0xFFD946EF),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Focus',
                            '$_focusScore%',
                            Icons.filter_center_focus_rounded,
                            const Color(0xFFA855F7),
                            isDark,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

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
                                    'Execution Rate',
                                    const Color(0xFF1D9E75),
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
                      'Pillar Breakdown',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TabBar(
                        controller: _pillarTabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor:
                            isDark ? Colors.white54 : const Color(0xFF64748B),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: _pillarTabController.index == 0
                                ? [
                                    const Color(0xFFD946EF),
                                    const Color(0xFFA855F7),
                                  ]
                                : [
                                    const Color(0xFF7E22CE),
                                    const Color(0xFF6366F1),
                                  ],
                          ),
                        ),
                        onTap: (_) => setState(() {}),
                        tabs: const [
                          Tab(text: 'BELIEF'),
                          Tab(text: 'FOCUS'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _pillarTabController,
                      builder: (context, _) {
                        return _pillarTabController.index == 0
                            ? _buildBeliefBreakdown(isDark)
                            : _buildFocusBreakdown(isDark);
                      },
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

  Widget _buildPillarScoreHeader({
    required bool isDark,
    required String title,
    required int scorePercent,
    required Color color,
    required List<Widget> stats,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$scorePercent%',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: stats),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBeliefBreakdown(bool isDark) {
    const color = Color(0xFFD946EF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPillarScoreHeader(
          isDark: isDark,
          title: 'BELIEF PILLAR',
          scorePercent: _beliefScore,
          color: color,
          stats: [
            _statChip(
              'Today',
              '$_beliefTasksDone/$_beliefTasksTotal tasks',
              color,
              isDark,
            ),
            _statChip(
              'Pts / task',
              _beliefPointsPerTask.toStringAsFixed(1),
              color,
              isDark,
            ),
            _statChip('→ ER', '${_beliefErContribution.toStringAsFixed(1)}', color, isDark),
            _statChip('→ GP', '+${_beliefGpContribution.toStringAsFixed(1)}', color, isDark),
          ],
        ),
        if (_beliefBreakdown.isEmpty)
          _emptyPillarMessage(isDark, 'No belief tasks configured on website.')
        else
          ..._beliefBreakdown.map((item) {
            final name = '${item['name'] ?? 'Task'}';
            final count = int.tryParse('${item['count'] ?? 0}') ?? 0;
            final pts =
                double.tryParse('${item['points_per_task'] ?? _beliefPointsPerTask}') ??
                _beliefPointsPerTask;
            final section = '${item['section_title'] ?? ''}'.trim();

            return _breakdownRow(
              isDark: isDark,
              color: color,
              icon: Icons.self_improvement_rounded,
              title: name,
              subtitle: section.isNotEmpty ? section : 'Mindset activity',
              count: count,
              countLabel: 'LOGS',
              pointsLabel: '${pts.toStringAsFixed(1)} pts',
              showOptimization: true,
            );
          }),
      ],
    );
  }

  Widget _buildFocusBreakdown(bool isDark) {
    const color = Color(0xFFA855F7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPillarScoreHeader(
          isDark: isDark,
          title: 'FOCUS PILLAR',
          scorePercent: _focusScore,
          color: color,
          stats: [
            _statChip('Clients', '$_focusClientCount active', color, isDark),
            _statChip('→ ER', '${_focusErContribution.toStringAsFixed(1)}', color, isDark),
            _statChip('→ GP', '+${_focusGpContribution.toStringAsFixed(1)}', color, isDark),
          ],
        ),
        Text(
          'Activity breakdown',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (_focusBreakdown.isEmpty)
          _emptyPillarMessage(isDark, 'No focus activity logged this period.')
        else
          ..._focusBreakdown.map((item) {
            final key = '${item['key'] ?? ''}';
            final label = '${item['label'] ?? key}';
            final count = int.tryParse('${item['count'] ?? 0}') ?? 0;
            final pts = int.tryParse('${item['points_per_client'] ?? 0}') ?? 0;
            final icon = _focusActivityIcons[key] ?? Icons.track_changes_rounded;

            return _breakdownRow(
              isDark: isDark,
              color: color,
              icon: icon,
              title: label,
              subtitle: 'Pipeline stage · $pts pts per client',
              count: count,
              countLabel: 'LOGS',
              pointsLabel: '$pts pts',
              showOptimization: true,
            );
          }),
        const SizedBox(height: 20),
        Text(
          'Clients by pipeline stage',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (_focusPipeline.isEmpty)
          _emptyPillarMessage(isDark, 'No clients in Deal Room pipeline.')
        else
          ..._focusPipeline.map((item) {
            final label = '${item['label'] ?? 'Stage'}';
            final clients = int.tryParse('${item['client_count'] ?? 0}') ?? 0;
            final pts = int.tryParse('${item['points_per_client'] ?? 0}') ?? 0;

            return _breakdownRow(
              isDark: isDark,
              color: color,
              icon: Icons.people_outline_rounded,
              title: label,
              subtitle: 'Active in pipeline',
              count: clients,
              countLabel: 'CLIENTS',
              pointsLabel: '$pts pts',
              showOptimization: false,
            );
          }),
      ],
    );
  }

  Widget _emptyPillarMessage(bool isDark, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _breakdownRow({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required String countLabel,
    required String pointsLabel,
    required bool showOptimization,
  }) {
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    countLabel,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pointsLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (showOptimization) ...[
                const SizedBox(width: 8),
                Text(
                  'Optimization Active',
                  style: TextStyle(
                    color: const Color(0xFF1D9E75),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  double _chartMaxY() {
    if (_data.isEmpty) return 100;
    final peak = _data.reduce((a, b) => a > b ? a : b);
    return peak <= 0 ? 100 : 100;
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
              if (value % 25 == 0) {
                return Text(
                  '${value.toInt()}%',
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
                '${flSpot.y.toInt()}%',
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
        LineChartBarData(
          spots: _data.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value.toDouble());
          }).toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: const Color(0xFF1D9E75),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF1D9E75),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
