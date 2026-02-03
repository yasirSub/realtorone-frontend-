import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    if (_isLoading) {
      return const SizedBox(height: 120, child: Center(child: EliteLoader()));
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'Growth Potential',
              'Higher',
              '$_growthScore',
              const Color(0xFF667eea),
              Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              'Execution Rate',
              'Peak',
              '$_executionRate%',
              const Color(0xFF4ECDC4),
              Icons.bolt_rounded,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildMetricCard(
    String title,
    String trend,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                color: color.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
