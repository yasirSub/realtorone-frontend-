import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class ResultsTrackerPage extends StatefulWidget {
  const ResultsTrackerPage({super.key});

  @override
  State<ResultsTrackerPage> createState() => _ResultsTrackerPageState();
}

class _ResultsTrackerPageState extends State<ResultsTrackerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _results = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _monthlyGraph = [];
  List<dynamic> _followUps = [];
  int _overdueCount = 0;
  String? _guardAlert;
  bool _hasClients = true;
  bool _checkedClientStatus = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadClientStatus();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadResults(), _loadMonthlyGraph(), _loadFollowUps()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadClientStatus() async {
    final response = await ApiClient.get(
      ApiEndpoints.clientsStatus,
      requiresAuth: true,
    );

    if (response['success'] == true) {
      setState(() {
        _hasClients = response['has_clients'] ?? false;
        _checkedClientStatus = true;
      });
    } else {
      setState(() {
        _checkedClientStatus = true;
      });
    }
  }

  Future<void> _loadResults() async {
    final response = await ApiClient.get(
      ApiEndpoints.results,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      setState(() {
        _results = response['data'] ?? [];
        _summary = response['summary'] ?? {};
      });
    }
  }

  Future<void> _loadMonthlyGraph() async {
    final response = await ApiClient.get(
      ApiEndpoints.resultsMonthlyGraph,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      setState(() => _monthlyGraph = response['data'] ?? []);
    }
  }

  Future<void> _loadFollowUps() async {
    final response = await ApiClient.get(
      ApiEndpoints.followUps,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      final data = response['data'] ?? {};
      setState(() {
        _followUps = data['pending'] ?? [];
        _overdueCount = data['overdue_count'] ?? 0;
        _guardAlert = data['guard_alert'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Results Intelligence',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D4AA),
          labelColor: const Color(0xFF00D4AA),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '📊 Pipeline'),
            Tab(text: '📞 Follow-ups'),
            Tab(text: '📈 Trends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPipelineTab(),
                _buildFollowUpsTab(),
                _buildTrendsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogResultDialog(),
        backgroundColor: const Color(0xFF00D4AA),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Log Result',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPipelineTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Follow-up Guard Alert
          if (_guardAlert != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade900.withValues(alpha: 0.6),
                    Colors.orange.shade900.withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade400.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _guardAlert!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Summary Cards
          Row(
            children: [
              _summaryCard(
                '🔥 Hot Leads',
                '${_summary['hot_leads'] ?? 0}',
                const Color(0xFFFF6B35),
              ),
              const SizedBox(width: 10),
              _summaryCard(
                '🤝 Deals',
                '${_summary['deals_closed'] ?? 0}',
                const Color(0xFF00D4AA),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard(
                '💰 Commission',
                '${(_summary['total_commission'] ?? 0).toStringAsFixed(0)} AED',
                const Color(0xFFFFD700),
              ),
              const SizedBox(width: 10),
              _summaryCard(
                '📊 Conversion',
                '${_summary['conversion_rate'] ?? 0}%',
                const Color(0xFF3498DB),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Results list
          const Text(
            'Recent Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty && _checkedClientStatus && !_hasClients)
            _buildFirstClientHero()
          else if (_results.isEmpty)
            _emptyState(
              'No results logged yet',
              'Tap + to log your first hot lead or deal!',
            )
          else
            ..._results.take(20).map((r) => _resultCard(r)),
        ],
      ),
    );
  }

  Widget _buildFollowUpsTab() {
    return RefreshIndicator(
      onRefresh: _loadFollowUps,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overdue counter
          if (_overdueCount > 0)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_overdueCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'overdue follow-ups!\nHot leads cool down fast.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          if (_followUps.isEmpty)
            _emptyState(
              'No pending follow-ups',
              'Great! You\'re on top of all your leads.',
            )
          else
            ..._followUps.map((f) => _followUpCard(f)),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '6-Month Pipeline Trend',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Simple bar chart
        if (_monthlyGraph.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F36),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _legendDot(const Color(0xFFFF6B35), 'Leads'),
                    const SizedBox(width: 16),
                    _legendDot(const Color(0xFF00D4AA), 'Deals'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _monthlyGraph.map<Widget>((m) {
                      final maxVal = _monthlyGraph.fold(1, (prev, item) {
                        final leads = (item['leads'] ?? 0) as int;
                        return leads > prev ? leads : prev;
                      });
                      final leads = (m['leads'] ?? 0) as int;
                      final deals = (m['deals'] ?? 0) as int;
                      final leadsH = maxVal > 0 ? (leads / maxVal) * 140 : 0.0;
                      final dealsH = maxVal > 0 ? (deals / maxVal) * 140 : 0.0;

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 12,
                                  height: leadsH.toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  width: 12,
                                  height: dealsH.toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D4AA),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m['label'] ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Commission trend
        const Text(
          'Commission by Month',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._monthlyGraph.map((m) {
          final commission = (m['commission'] ?? 0).toDouble();
          final maxCommission = _monthlyGraph.fold(1.0, (prev, item) {
            final c = (item['commission'] ?? 0).toDouble();
            return c > prev ? c : prev;
          });
          final barWidth = maxCommission > 0
              ? (commission / maxCommission)
              : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F36),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 35,
                  child: Text(
                    m['label'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth.toDouble(),
                      backgroundColor: Colors.white12,
                      color: const Color(0xFFFFD700),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${commission.toStringAsFixed(0)} AED',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(dynamic result) {
    final type = result['type'] ?? '';
    final icon = type == 'hot_lead'
        ? '🔥'
        : type == 'deal_closed'
        ? '🤝'
        : '💰';
    final label = type == 'hot_lead'
        ? 'Hot Lead'
        : type == 'deal_closed'
        ? 'Deal Closed'
        : 'Commission';
    final color = type == 'hot_lead'
        ? const Color(0xFFFF6B35)
        : type == 'deal_closed'
        ? const Color(0xFF00D4AA)
        : const Color(0xFFFFD700);
    final value = result['value'] ?? 0;
    final date = result['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (result['client_name'] != null)
                  Text(
                    result['client_name'],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                if (result['property_name'] != null)
                  Text(
                    result['property_name'],
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                Text(
                  date,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (value > 0)
            Text(
              '${value.toStringAsFixed(0)} AED',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _followUpCard(dynamic followUp) {
    final isOverdue = followUp['is_overdue'] == true;
    final priority = followUp['priority'] ?? 1;
    final priorityColor = priority == 3
        ? Colors.red
        : priority == 2
        ? Colors.orange
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade900.withValues(alpha: 0.15)
            : const Color(0xFF1A1F36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade700.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  followUp['client_name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Due: ${followUp['due_at'] ?? ''}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red.shade300 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (followUp['notes'] != null)
                  Text(
                    followUp['notes'],
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF00D4AA),
            ),
            onPressed: () => _completeFollowUp(followUp['id']),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFirstClientHero() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020617), Color(0xFF111827)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Skyline placeholder
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF020617), Color(0xFF1E293B)],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'THE DEAL ROOM',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'The skyline is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your deals aren’t… yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your first client to start your ascent.\nEvery skyline starts with one deal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () => _showLogResultDialog(firstClient: true),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Add First Client',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CLIENTS • REVENUE',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogResultDialog({bool firstClient = false}) {
    String selectedType = 'hot_lead';
    final clientController = TextEditingController();
    final propertyController = TextEditingController();
    final valueController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedSource;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1F36),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      firstClient ? 'Add First Client' : 'Log Result',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type selector
                    Row(
                      children: [
                        _typeChip(
                          '🔥 Lead',
                          'hot_lead',
                          selectedType,
                          (t) => setModalState(() => selectedType = t),
                        ),
                        const SizedBox(width: 8),
                        _typeChip(
                          '🤝 Deal',
                          'deal_closed',
                          selectedType,
                          (t) => setModalState(() => selectedType = t),
                        ),
                        const SizedBox(width: 8),
                        _typeChip(
                          '💰 Commission',
                          'commission',
                          selectedType,
                          (t) => setModalState(() => selectedType = t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _inputField(
                      'Client Name',
                      clientController,
                      'e.g. Ahmed Al Maktoum',
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      'Property',
                      propertyController,
                      'e.g. Marina Tower 2BR',
                    ),
                    const SizedBox(height: 12),

                    // Source dropdown
                    const Text(
                      'Lead Source',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E21),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1F36),
                          value: selectedSource,
                          hint: const Text(
                            'Select source',
                            style: TextStyle(color: Colors.white38),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'bayut',
                              child: Text(
                                '🏠 Bayut',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'property_finder',
                              child: Text(
                                '🔍 Property Finder',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'instagram',
                              child: Text(
                                '📸 Instagram',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'referral',
                              child: Text(
                                '🤝 Referral',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'cold_call',
                              child: Text(
                                '📞 Cold Call',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'walk_in',
                              child: Text(
                                '🚶 Walk-in',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'linkedin',
                              child: Text(
                                '💼 LinkedIn',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(
                                '📋 Other',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => selectedSource = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (selectedType == 'deal_closed' ||
                        selectedType == 'commission')
                      _inputField(
                        'Value (AED)',
                        valueController,
                        'e.g. 50000',
                        isNumber: true,
                      ),
                    const SizedBox(height: 12),
                    _inputField('Notes', notesController, 'Optional notes...'),
                    const SizedBox(height: 20),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _submitResult(
                          type: selectedType,
                          clientName: clientController.text,
                          propertyName: propertyController.text,
                          source: selectedSource,
                          value: double.tryParse(valueController.text) ?? 0,
                          notes: notesController.text,
                        ),
                        child: const Text(
                          'Log Result ✨',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _typeChip(
    String label,
    String value,
    String selected,
    Function(String) onTap,
  ) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00D4AA).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00D4AA) : Colors.white24,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00D4AA) : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0A0E21),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00D4AA)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitResult({
    required String type,
    required String clientName,
    required String propertyName,
    String? source,
    double value = 0,
    String notes = '',
  }) async {
    Navigator.pop(context);

    final response = await ApiClient.post(ApiEndpoints.results, {
      'type': type,
      'client_name': clientName.isNotEmpty ? clientName : null,
      'property_name': propertyName.isNotEmpty ? propertyName : null,
      'source': source,
      'value': value,
      'notes': notes.isNotEmpty ? notes : null,
    }, requiresAuth: true);

    if (response['success'] == true) {
      final data = response['data'] ?? {};
      final newBadges = data['new_badges'] as List? ?? [];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Result logged! Score: ${data['daily_score'] ?? 0}'),
          backgroundColor: const Color(0xFF00D4AA),
        ),
      );

      // Show badge notification if any
      for (final badge in newBadges) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🏆 Badge unlocked: ${badge['name']} ${badge['icon']}',
              ),
              backgroundColor: Colors.amber.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${response['message'] ?? 'Failed'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeFollowUp(int id) async {
    final response = await ApiClient.put(
      ApiEndpoints.completeFollowUp(id),
      {},
      requiresAuth: true,
    );

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Follow-up completed! +${response['data']?['points_earned'] ?? 0} points',
          ),
          backgroundColor: const Color(0xFF00D4AA),
        ),
      );
      _loadFollowUps();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
