import 'package:flutter/material.dart';
import '../../api/admin_api.dart';
import '../../widgets/elite_loader.dart';

class AdminManageSubscriptionPage extends StatefulWidget {
  const AdminManageSubscriptionPage({super.key});

  @override
  State<AdminManageSubscriptionPage> createState() =>
      _AdminManageSubscriptionPageState();
}

class _AdminManageSubscriptionPageState
    extends State<AdminManageSubscriptionPage> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _couponController = TextEditingController();

  List<dynamic> _results = [];
  Map<String, dynamic>? _selectedUser;
  Map<String, dynamic>? _pricingPreview;
  String _tier = 'Rainmaker';
  int _months = 1;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isPreviewLoading = false;
  String? _message;
  bool _messageIsError = false;

  static const _tiers = ['Consultant', 'Rainmaker', 'Titan'];
  static const _monthOptions = [1, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_schedulePreview);
    _couponController.addListener(_schedulePreview);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _schedulePreview() {
    if (_tier == 'Consultant' || _selectedUser == null) return;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _loadPricingPreview();
    });
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      setState(() {
        _message = 'Type at least 2 characters to search';
        _messageIsError = true;
        _results = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _message = null;
    });

    try {
      final res = await AdminApi.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = res['success'] == true ? (res['data'] as List? ?? []) : [];
        _isSearching = false;
        if (_results.isEmpty) {
          _message = 'No users found';
          _messageIsError = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _message = 'Search failed: $e';
        _messageIsError = true;
      });
    }
  }

  Future<void> _loadPricingPreview() async {
    if (_selectedUser == null || _tier == 'Consultant') {
      setState(() => _pricingPreview = null);
      return;
    }

    final userId = int.tryParse(_selectedUser!['id']?.toString() ?? '');
    if (userId == null) return;

    double? amountPaid;
    final amountText = _amountController.text.trim();
    if (amountText.isNotEmpty) {
      amountPaid = double.tryParse(amountText);
    }

    final couponCode = _couponController.text.trim();

    setState(() => _isPreviewLoading = true);

    try {
      final res = await AdminApi.previewSubscriptionPricing(
        userId: userId,
        tierName: _tier,
        months: _months,
        amountPaid: amountPaid,
        couponCode: couponCode.isEmpty ? null : couponCode,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _pricingPreview = Map<String, dynamic>.from(res['data'] as Map);
          _isPreviewLoading = false;
        });
      } else {
        setState(() {
          _pricingPreview = null;
          _isPreviewLoading = false;
          _message = res['message']?.toString();
          _messageIsError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pricingPreview = null;
        _isPreviewLoading = false;
      });
    }
  }

  Future<void> _grant() async {
    if (_selectedUser == null) {
      setState(() {
        _message = 'Select a user first';
        _messageIsError = true;
      });
      return;
    }

    final userId = int.tryParse(_selectedUser!['id']?.toString() ?? '');
    if (userId == null) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    double? amountPaid;
    final amountText = _amountController.text.trim();
    if (amountText.isNotEmpty) {
      amountPaid = double.tryParse(amountText);
    }

    final couponCode = _couponController.text.trim();

    try {
      final res = await AdminApi.grantSubscription(
        userId: userId,
        tierName: _tier,
        months: _tier == 'Consultant' ? null : _months,
        amountPaid: amountPaid,
        couponCode: couponCode.isEmpty ? null : couponCode,
        adminNote: _noteController.text.trim().isEmpty
            ? 'Manual tier change from mobile admin'
            : _noteController.text.trim(),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _isSaving = false;
          _message = res['message']?.toString() ?? 'Subscription updated';
          _messageIsError = false;
          _selectedUser =
              res['user'] as Map<String, dynamic>? ?? _selectedUser;
        });
        await _loadPricingPreview();
      } else {
        setState(() {
          _isSaving = false;
          _message = res['message']?.toString() ?? 'Update failed';
          _messageIsError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Update failed: $e';
        _messageIsError = true;
      });
    }
  }

  Widget _buildPricingPreviewCard(bool isDark) {
    final p = _pricingPreview;
    if (_tier == 'Consultant' || p == null) {
      return const SizedBox.shrink();
    }

    final list = _num(p['amount_before_discount']);
    final discount = _num(p['discount_amount']);
    final paid = _num(p['amount_paid']);
    final couponRejected = p['coupon_rejected'] == true;
    final couponApplied = p['coupon_applied'] == true;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Pricing preview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_isPreviewLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _previewRow('List total (AED)', list.toStringAsFixed(2)),
            _previewRow('Total discount (AED)', discount.toStringAsFixed(2)),
            _previewRow(
              'Amount recorded (AED)',
              paid.toStringAsFixed(2),
              bold: true,
            ),
            if (couponApplied)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Coupon applied to ledger',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            if (couponRejected)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Coupon not valid for this tier/duration',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage user subscription'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Search by name or email, then assign tier. Optional coupon or amount paid updates the subscription ledger.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search user…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSearching ? null : _search,
                    child: const Text('Search'),
                  ),
                ],
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._results.map((u) {
                  final map = Map<String, dynamic>.from(u as Map);
                  final selected = _selectedUser?['id'] == map['id'];
                  return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text(map['name']?.toString() ?? 'User'),
                      subtitle: Text(
                        '${map['email'] ?? ''}\nTier: ${map['membership_tier'] ?? 'Consultant'}',
                      ),
                      isThreeLine: true,
                      onTap: () {
                        setState(() => _selectedUser = map);
                        _loadPricingPreview();
                      },
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  );
                }),
              ],
              if (_selectedUser != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Selected: ${_selectedUser!['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _tier,
                  decoration: const InputDecoration(
                    labelText: 'Tier',
                    border: OutlineInputBorder(),
                  ),
                  items: _tiers
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _tier = v ?? 'Rainmaker');
                    _loadPricingPreview();
                  },
                ),
                if (_tier != 'Consultant') ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Duration (months)',
                      border: OutlineInputBorder(),
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: _monthOptions.map((m) {
                        final selected = _months == m;
                        return ChoiceChip(
                          label: Text(m == 12 ? '12 (1 yr)' : '$m'),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _months = m);
                            _loadPricingPreview();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon code (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loadPricingPreview(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount paid (AED, optional)',
                      hintText:
                          'Leave empty to use list price (after coupon)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  _buildPricingPreviewCard(isDark),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Admin note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _grant,
                    child: Text(
                      _tier == 'Consultant'
                          ? 'Downgrade to Consultant'
                          : 'Apply $_tier for $_months mo',
                    ),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError ? Colors.redAccent : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (_isSearching || _isSaving) EliteLoader.top(),
        ],
      ),
    );
  }
}
