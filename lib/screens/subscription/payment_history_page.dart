import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../api/subscription_api.dart';
import '../../widgets/elite_loader.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SubscriptionApi.getPaymentHistory();
      if (!mounted) return;

      if (response['success'] == true) {
        final raw = response['data'];
        setState(() {
          _items = raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ??
              'Could not load payment history.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load payment history. Check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Payment History'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: EliteLoader())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(onPressed: _loadHistory, child: const Text('Retry')),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No payments yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Successful, failed, and pending subscription payments will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _PaymentHistoryCard(
                            item: _items[index],
                            isDark: isDark,
                          )
                              .animate()
                              .fadeIn(duration: 280.ms, delay: (40 * index).ms)
                              .slideY(begin: 0.04, end: 0);
                        },
                      ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.item,
    required this.isDark,
  });

  final Map<String, dynamic> item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'pending';
    final description = item['description']?.toString() ??
        item['package_name']?.toString() ??
        'Subscription payment';
    final amount = double.tryParse(item['amount']?.toString() ?? '') ?? 0;
    final currency = item['currency']?.toString() ?? 'AED';
    final method = _formatMethod(item['payment_method']?.toString());
    final failureReason = item['failure_reason']?.toString();
    final createdAt = _formatDate(item['created_at']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      createdAt,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Amount',
                  value: _formatAmount(amount, currency),
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _InfoTile(
                  label: 'Method',
                  value: method,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (failureReason != null && failureReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                failureReason,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatMethod(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'apple':
        return 'App Store';
      case 'google':
        return 'Google Play';
      case 'razorpay':
        return 'Razorpay';
      case 'admin':
        return 'Admin grant';
      case 'stripe':
        return 'Stripe';
      case 'paypal':
        return 'PayPal';
      default:
        return raw == null || raw.isEmpty ? 'Unknown' : raw;
    }
  }

  static String _formatAmount(double amount, String currency) {
    if (amount <= 0) return '—';
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    if (currency.toUpperCase() == 'INR') {
      return '$symbol${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'success' => ('Paid', const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'failed' => ('Failed', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'cancelled' => ('Cancelled', const Color(0xFFE2E8F0), const Color(0xFF475569)),
      _ => ('Pending', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
