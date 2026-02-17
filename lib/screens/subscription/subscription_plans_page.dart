// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../api/subscription_api.dart';
import '../../api/api_client.dart';
import '../../widgets/elite_loader.dart';

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _packages = [];
  Map<String, dynamic>? _currentSub;
  String _currentTier = 'Consultant';
  bool _isPremium = false;
  String? _expiresAt;

  // Coupon
  final _couponController = TextEditingController();
  Map<String, dynamic>? _validatedCoupon;
  bool _isValidatingCoupon = false;
  String? _couponError;

  // Selected
  int? _selectedPackageId;
  int _selectedMonths = 1;
  bool _isPurchasing = false;

  // Tier config
  static const _tierIcons = {
    'Consultant': Icons.star_border_rounded,
    'Rainmaker': Icons.workspace_premium_rounded,
    'Titan': Icons.emoji_events_rounded,
    'Titan - GOLD': Icons.emoji_events_rounded, // Legacy support
    'Titan-GOLD': Icons.emoji_events_rounded, // Legacy support
    // Legacy support
    'Free': Icons.star_border_rounded,
    'Silver': Icons.workspace_premium_rounded,
    'Gold': Icons.emoji_events_rounded,
    'Platinum': Icons.bolt_rounded,
    'Diamond': Icons.auto_awesome_rounded,
  };

  static const _tierGradients = {
    'Consultant': [Color(0xFF64748B), Color(0xFF475569)],
    'Rainmaker': [Color(0xFF94A3B8), Color(0xFF64748B)],
    'Titan': [Color(0xFFF59E0B), Color(0xFFD97706)],
    'Titan - GOLD': [Color(0xFFF59E0B), Color(0xFFD97706)], // Legacy support
    'Titan-GOLD': [Color(0xFFF59E0B), Color(0xFFD97706)], // Legacy support
    // Legacy support
    'Free': [Color(0xFF64748B), Color(0xFF475569)],
    'Silver': [Color(0xFF94A3B8), Color(0xFF64748B)],
    'Gold': [Color(0xFFF59E0B), Color(0xFFD97706)],
    'Platinum': [Color(0xFFD946EF), Color(0xFF7C3AED)],
    'Diamond': [Color(0xFF7C3AED), Color(0xFF6D28D9)],
  };

  static const _tierGlow = {
    'Consultant': Color(0xFF64748B),
    'Rainmaker': Color(0xFF94A3B8),
    'Titan': Color(0xFFF59E0B),
    'Titan - GOLD': Color(0xFFF59E0B), // Legacy support
    'Titan-GOLD': Color(0xFFF59E0B), // Legacy support
    // Legacy support
    'Free': Color(0xFF64748B),
    'Silver': Color(0xFF94A3B8),
    'Gold': Color(0xFFF59E0B),
    'Platinum': Color(0xFFD946EF),
    'Diamond': Color(0xFF7C3AED),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Clear cache before fetching to ensure fresh tier names
      await ApiClient.clearCache();
      final results = await Future.wait([
        SubscriptionApi.getPackages(),
        SubscriptionApi.getMySubscription(),
      ]);

      final packagesRes = results[0];
      final subRes = results[1];

      if (mounted) {
        setState(() {
          if (packagesRes['success'] == true) {
            _packages = packagesRes['data'] ?? [];
          }
          if (subRes['success'] == true) {
            _currentSub = subRes['data'];
            _isPremium = subRes['is_premium'] == true;
            _currentTier = subRes['membership_tier'] ?? 'Consultant';
            _expiresAt = subRes['expires_at'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _validatedCoupon = null;
    });

    try {
      final res = await SubscriptionApi.validateCoupon(code);
      if (mounted) {
        setState(() {
          _isValidatingCoupon = false;
          if (res['success'] == true) {
            _validatedCoupon = res['data'];
          } else {
            _couponError = res['message'] ?? 'Invalid coupon';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidatingCoupon = false;
          _couponError = 'Connection error';
        });
      }
    }
  }

  Future<void> _purchasePackage() async {
    if (_selectedPackageId == null) return;

    setState(() => _isPurchasing = true);

    try {
      // Simulated PayPal payment ID
      final paymentId = 'PAYPAL_SIM_${DateTime.now().millisecondsSinceEpoch}';

      final res = await SubscriptionApi.purchaseSubscription(
        packageId: _selectedPackageId!,
        months: _selectedMonths,
        paymentId: paymentId,
        couponId: _validatedCoupon != null
            ? (_validatedCoupon!['id'] as num).toInt()
            : null,
      );

      if (mounted) {
        setState(() => _isPurchasing = false);
        if (res['success'] == true) {
          _showSuccessDialog();
          _loadData(); // Refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Purchase failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text(
                'SUBSCRIPTION ACTIVATED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to the $_currentTier tier!',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(true); // Return success
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'LET\'S GO',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculatePrice(Map<String, dynamic> pkg) {
    double price =
        (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0) *
        _selectedMonths;
    if (_validatedCoupon != null) {
      final discount = (_validatedCoupon!['discount_percentage'] as num?) ?? 0;
      price = price * (1 - discount / 100);
    }
    return price;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF1E293B),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                        ),
                      ),
                      // Decorative circles
                      Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF667eea).withOpacity(0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: -40,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF7C3AED).withOpacity(0.06),
                          ),
                        ),
                      ),
                      // Content
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'SUBSCRIPTION',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ).animate().fadeIn().slideX(begin: -0.1),
                                  const SizedBox(width: 10),
                                  Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (_tierGlow[_currentTier] ??
                                                      const Color(0xFF64748B))
                                                  .withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color:
                                                (_tierGlow[_currentTier] ??
                                                        const Color(0xFF64748B))
                                                    .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _currentTier.toUpperCase(),
                                          style: TextStyle(
                                            color:
                                                _tierGlow[_currentTier] ??
                                                const Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 200.ms)
                                      .scale(begin: const Offset(0.8, 0.8)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                    _isPremium
                                        ? 'Your premium plan is active'
                                        : 'Choose a plan to unlock premium features',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms)
                                  .slideX(begin: -0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Current Plan Banner (if premium)
              if (_isPremium && _currentSub != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildCurrentPlanBanner(isDark),
                  ),
                ),

              // Duration Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildDurationSelector(isDark),
                ),
              ),

              // Package Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final pkg = _packages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPackageCard(pkg, isDark, index),
                    );
                  }, childCount: _packages.length),
                ),
              ),

              // Coupon Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildCouponSection(isDark),
                ),
              ),

              // Bottom spacer
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // Bottom Purchase Bar
          if (_selectedPackageId != null && !_isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildPurchaseBar(isDark),
            ),

          if (_isLoading || _isPurchasing) EliteLoader.top(),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanBanner(bool isDark) {
    final gradients =
        _tierGradients[_currentTier] ??
        [const Color(0xFF64748B), const Color(0xFF475569)];
    final expDate = _expiresAt != null ? DateTime.tryParse(_expiresAt!) : null;
    final daysLeft = expDate != null
        ? expDate.difference(DateTime.now()).inDays
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradients),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradients[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _tierIcons[_currentTier] ?? Icons.star_border_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_currentTier Plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daysLeft > 0 ? '$daysLeft days remaining' : 'Plan expired',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildDurationSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [1, 3, 6, 12].map((m) {
          final isSelected = _selectedMonths == m;
          final label = m == 1
              ? '1 Mo'
              : m == 12
              ? '1 Year'
              : '$m Mo';
          final savings = m == 3
              ? '-5%'
              : m == 6
              ? '-10%'
              : m == 12
              ? '-20%'
              : null;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMonths = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (savings != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        savings,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : const Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, bool isDark, int index) {
    final name = pkg['name']?.toString() ?? 'Package';
    // Remove "GOLD" from display name
    final displayName = name
        .replaceAll(' - GOLD', '')
        .replaceAll('- GOLD', '')
        .replaceAll(' GOLD', '')
        .replaceAll('GOLD', '')
        .trim();
    final id = (pkg['id'] as num?)?.toInt() ?? 0;
    final priceMonthly =
        double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0;
    final features = (pkg['features'] as List?)?.cast<String>() ?? [];
    final description = pkg['description']?.toString() ?? '';
    final isSelected = _selectedPackageId == id;
    final isCurrentTier = name == _currentTier;
    final isFree = priceMonthly == 0;
    
    // Determine if Titan or Rainmaker for special styling
    final isTitan = name.toLowerCase().contains('titan');
    final isRainmaker = name.toLowerCase().contains('rainmaker');
    
    // Get gradients and glow colors (support both old and new names)
    final gradients = _tierGradients[name] ?? 
                      (isTitan ? _tierGradients['Titan'] : null) ??
                      (isRainmaker ? _tierGradients['Rainmaker'] : null) ??
                      [const Color(0xFF667eea), const Color(0xFF764ba2)];
    final glowColor = _tierGlow[name] ?? 
                      (isTitan ? _tierGlow['Titan'] : null) ??
                      (isRainmaker ? _tierGlow['Rainmaker'] : null) ??
                      const Color(0xFF667eea);
    
    // Card background color based on tier
    final cardBgColor = isTitan
        ? (isDark 
            ? const Color(0xFF1E293B).withOpacity(0.8)
            : Colors.white)
        : isRainmaker
        ? (isDark 
            ? const Color(0xFF1E293B).withOpacity(0.8)
            : Colors.white)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    
    // Tier-specific background gradient overlay
    final bgGradient = isTitan
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF59E0B).withOpacity(0.1),
              const Color(0xFFD97706).withOpacity(0.05),
            ],
          )
        : isRainmaker
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF94A3B8).withOpacity(0.1),
              const Color(0xFF64748B).withOpacity(0.05),
            ],
          )
        : null;

    return GestureDetector(
          onTap: isFree || isCurrentTier
              ? null
              : () =>
                    setState(() => _selectedPackageId = isSelected ? null : id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              gradient: bgGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? glowColor
                    : isCurrentTier
                    ? glowColor.withOpacity(0.3)
                    : (isTitan || isRainmaker)
                    ? glowColor.withOpacity(0.2)
                    : Colors.transparent,
                width: isSelected ? 2.5 : (isTitan || isRainmaker) ? 1.5 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: glowColor.withOpacity(0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                if (isTitan || isRainmaker)
                  BoxShadow(
                    color: glowColor.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradients),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _tierIcons[name] ?? Icons.star_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName.toUpperCase(),
                                style: TextStyle(
                                  color: isTitan
                                      ? const Color(0xFFF59E0B)
                                      : isRainmaker
                                      ? const Color(0xFF94A3B8)
                                      : (isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B)),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isCurrentTier) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isFree)
                          Text(
                            'FREE',
                            style: TextStyle(
                              color: glowColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        else ...[
                          Text(
                            '\$${priceMonthly.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isTitan
                                  ? const Color(0xFFF59E0B)
                                  : isRainmaker
                                  ? const Color(0xFF94A3B8)
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B)),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            '/month',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Features
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: features
                          .take(5)
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: glowColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                // Select action
                if (!isFree && !isCurrentTier) ...[
                  const SizedBox(height: 14),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? glowColor
                          : glowColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        isSelected ? '✓ SELECTED' : 'SELECT PLAN',
                        style: TextStyle(
                          color: isSelected ? Colors.white : glowColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn()
        .slideY(begin: 0.08);
  }

  Widget _buildCouponSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROMO CODE',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F5F9),
                    suffixIcon: _validatedCoupon != null
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isValidatingCoupon ? null : _validateCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'APPLY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_couponError != null) ...[
            const SizedBox(height: 8),
            Text(
              _couponError!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_validatedCoupon != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_validatedCoupon!['discount_percentage']}% discount applied!',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildPurchaseBar(bool isDark) {
    final pkg = _packages.firstWhere(
      (p) => (p['id'] as num?)?.toInt() == _selectedPackageId,
      orElse: () => <String, dynamic>{},
    );
    if (pkg.isEmpty) return const SizedBox();

    final name = pkg['name']?.toString() ?? 'Plan';
    final totalPrice = _calculatePrice(pkg);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                .withOpacity(0.92),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$name · $_selectedMonths ${_selectedMonths == 1 ? 'month' : 'months'}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isPurchasing ? null : _purchasePackage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                  child: const Text(
                    'SUBSCRIBE NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
