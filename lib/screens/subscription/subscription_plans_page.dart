// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/app_config.dart';
import '../../api/subscription_api.dart';
import '../../api/api_client.dart';
import '../../services/iap_service.dart';
import '../../services/razorpay_service.dart';
import '../../widgets/elite_loader.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/subscription_pricing.dart';
import '../legal/legal_document_webview_page.dart';

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

  // Selected
  int? _selectedPackageId;
  int _selectedMonths = 3;
  bool _isPurchasing = false;
  bool _razorpayEnabled = false;
  bool _appleIapEnabled = true;
  bool _googleIapEnabled = true;
  String _paymentMethod = 'iap';

  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  String? _couponMessage;
  bool _isValidatingCoupon = false;

  bool get _isIos => Theme.of(context).platform == TargetPlatform.iOS;

  bool get _iapEnabledForPlatform =>
      _isIos ? _appleIapEnabled : _googleIapEnabled;

  bool get _showPaymentMethodPicker =>
      _isMobileIap && _razorpayEnabled && _iapEnabledForPlatform;

  int? get _appliedCouponId {
    final id = _appliedCoupon?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  int get _appliedCouponDiscountPercent {
    final v = _appliedCoupon?['discount_percentage'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool get _isMobileIap {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS ||
        platform == TargetPlatform.android;
  }

  String get _mobileStoreName =>
      _isIos ? 'App Store' : 'Google Play';

  String? _storeListedPrice(Map<String, dynamic> pkg) {
    final tierName = _normalizeTierName(pkg['name']?.toString() ?? '');
    return IapService()
        .findProductForTier(tierName, _selectedMonths)
        ?.price;
  }

  bool _looksLikeSandboxTestBilling(String? storePriceLabel) {
    if (storePriceLabel == null) return false;
    final lower = storePriceLabel.toLowerCase();
    return lower.contains('5 min') || lower.contains('/min');
  }

  Future<bool> _confirmBeforeMobilePurchase(Map<String, dynamic> pkg) async {
    if (!_isMobileIap) return true;

    final storePrice = _storeListedPrice(pkg) ??
        SubscriptionPricing.formatAedTotal(_calculatePrice(pkg));
    final hasCoupon = _appliedCoupon != null;
    final sandboxTest = _looksLikeSandboxTestBilling(storePrice);

    if (!hasCoupon && !sandboxTest) return true;

    final ledgerAfter = SubscriptionPricing.formatAedTotal(
      _calculatePriceAfterCoupon(pkg),
    );

    final buffer = StringBuffer();
    if (hasCoupon) {
      buffer.writeln(
        'Your $_appliedCouponDiscountPercent% coupon is applied when RealtorOne activates your subscription after payment.',
      );
      buffer.writeln();
      buffer.writeln('• $_mobileStoreName charge today: $storePrice');
      buffer.writeln('• Recorded plan value after coupon: $ledgerAfter');
      buffer.writeln();
      buffer.writeln(
        '$_mobileStoreName always shows the full product price in its payment sheet. '
        'Custom coupon discounts cannot appear there unless we configure matching promotional offers in the store console.',
      );
    }
    if (sandboxTest) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(
        'Test subscription: "/5 min" is a Google Play sandbox renewal interval (renews every 5 minutes for testing). '
        'Production plans bill monthly or per your selected term. Test purchases are not charged real money.',
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          hasCoupon ? 'Before you subscribe' : 'Test subscription',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            buffer.toString().trim(),
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(hasCoupon ? 'Continue to $_mobileStoreName' : 'Continue'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

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
    'Rainmaker': [Color(0xFF6366F1), Color(0xFF4F46E5)],
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
    'Rainmaker': Color(0xFF6366F1),
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
    RazorpayService().dispose();
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
        IapService().fetchProducts(IapService.allProductIds),
        SubscriptionApi.getRazorpayConfig(),
      ]);

      final packagesRes = results[0] as Map<String, dynamic>;
      final subRes = results[1] as Map<String, dynamic>;
      final rzRes = results[3] as Map<String, dynamic>;

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

            // If user is already premium, pre-select their current package
            // so "Manage billing" (1/6/12 months) is one tap.
            final currentPkgId = int.tryParse(_currentSub?['package_id']?.toString() ?? '');
            _selectedPackageId = _isPremium ? currentPkgId : null;
            _adjustSelectedDuration(_selectedPackageId);
          }
          _razorpayEnabled = rzRes['enabled'] == true;
          final paySettings = rzRes['payment_settings'];
          if (paySettings is Map) {
            _appleIapEnabled = paySettings['apple_iap_enabled'] != false;
            _googleIapEnabled = paySettings['google_iap_enabled'] != false;
            _razorpayEnabled = paySettings['razorpay_enabled'] == true;
          }
          if (_isMobileIap) {
            if (!_iapEnabledForPlatform && _razorpayEnabled) {
              _paymentMethod = 'razorpay';
            } else if (_iapEnabledForPlatform && !_razorpayEnabled) {
              _paymentMethod = 'iap';
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchasePackage() async {
    if (_selectedPackageId == null) return;

    // Find the selected package to get its tier name
    final pkg = _packages.firstWhere(
      (p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == _selectedPackageId,
      orElse: () => <String, dynamic>{},
    );
    if (pkg.isEmpty) return;

    final tierName = _normalizeTierName(pkg['name']?.toString() ?? 'Consultant');

    final isMobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    if (isMobile && _paymentMethod == 'razorpay' && _razorpayEnabled) {
      await _purchaseWithRazorpay(pkg);
      return;
    }

    if (isMobile && !_iapEnabledForPlatform) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'App Store / Google Play billing is disabled. Choose Razorpay or contact support.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (isMobile) {
      if (!await _confirmBeforeMobilePurchase(pkg)) return;

      setState(() => _isPurchasing = true);
      try {
        IapService().onPurchaseResult = (success, message) async {
          if (mounted) {
            setState(() => _isPurchasing = false);
            if (success) {
              await ApiClient.clearCache();
              await _loadData();
              if (mounted) {
                _showSuccessDialog();
              }
            } else if (message != null) {
              // Check if user cancelled to avoid showing annoying errors
              if (message.contains('cancelled') ||
                  message.contains('Canceled')) {
                return;
              }

              // Provide a more helpful message for common store issues (like emulators)
              String displayMessage = message;
              if (message.toLowerCase().contains('store not available')) {
                displayMessage =
                    'Payment services are not available on this device (Emulator). Please use a physical phone with a logged-in Google Play or App Store account.';
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(displayMessage),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        };
        IapService().pendingCouponId = _appliedCouponId;
        await IapService().buyByTier(
          tierName,
          _selectedMonths,
          _selectedPackageId!,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isPurchasing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initiate purchase: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    if (kIsWeb && _razorpayEnabled) {
      final uri = Uri.parse('${AppConfig.liveWebOrigin}/subscribe');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Web platform: show a message directing to the app
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use the mobile app to purchase subscriptions.'),
          backgroundColor: Color(0xFF667eea),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _purchaseWithRazorpay(Map<String, dynamic> pkg) async {
    if (_selectedPackageId == null) return;

    setState(() => _isPurchasing = true);
    try {
      final orderRes = await SubscriptionApi.createRazorpayOrder(
        packageId: _selectedPackageId!,
        months: _selectedMonths,
        couponId: _appliedCouponId,
      );

      if (orderRes['success'] != true) {
        throw Exception(
          orderRes['message']?.toString() ??
              'Could not start Razorpay checkout.',
        );
      }

      final data = orderRes['data'] as Map<String, dynamic>? ?? {};
      final packageName = pkg['name']?.toString() ?? 'Plan';
      final amount = int.tryParse(data['amount']?.toString() ?? '') ?? 0;

      await RazorpayService().openCheckout(
        keyId: data['key_id']?.toString() ?? '',
        orderId: data['order_id']?.toString() ?? '',
        amountPaise: amount,
        currency: data['currency']?.toString() ?? 'INR',
        description: '$packageName — $_selectedMonths month(s)',
        onSuccess: (paymentId, orderId, signature) async {
          final verify = await SubscriptionApi.verifyRazorpayPayment(
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );
          if (verify['success'] != true) {
            throw Exception(
              verify['message']?.toString() ?? 'Payment verification failed.',
            );
          }
          if (mounted) {
            await ApiClient.clearCache();
            await _loadData();
            _showSuccessDialog();
          }
        },
        onError: (message) {
          if (!mounted) return;
          if (message.toLowerCase().contains('cancel')) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  bool _isPackageComingSoon(Map<String, dynamic> pkg) {
    if (!_isIos) return false;
    final tierName = _normalizeTierName(pkg['name']?.toString() ?? 'Consultant');
    return !IapService().hasAnyProductForTierDuration(tierName, _selectedMonths);
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
              if (IapService().lastActivationCouponApplied) ...[
                const SizedBox(height: 12),
                Text(
                  _activationSuccessCouponLine(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
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

  String _activationSuccessCouponLine() {
    final pricing = IapService().lastActivationPricing;
    if (pricing == null) {
      return 'Your coupon was recorded on your subscription.';
    }
    final discount = pricing['discount_amount'] ?? pricing['coupon_discount_amount'];
    final amountPaid = pricing['amount_paid'];
    if (discount != null && (double.tryParse(discount.toString()) ?? 0) > 0) {
      return 'Coupon recorded: AED $discount off (ledger amount AED $amountPaid).';
    }
    return 'Your coupon was recorded on your subscription.';
  }

  /// Normalize tier name for deduplication (Titan, Titan-GOLD, Titan - GOLD → Titan)
  String _normalizeTierName(String name) {
    return name
        .replaceAll(' - GOLD', '')
        .replaceAll('- GOLD', '')
        .replaceAll(' GOLD', '')
        .replaceAll('GOLD', '')
        .trim()
        .toLowerCase();
  }

  Color _getGlowForSelectedPackage() {
    const defaultGlow = Color(0xFF667eea);
    if (_selectedPackageId == null) return defaultGlow;

    dynamic selectedPkg;
    for (final p in _packages) {
      final id = int.tryParse(p['id']?.toString() ?? '');
      if (id != null && id == _selectedPackageId) {
        selectedPkg = p;
        break;
      }
    }
    if (selectedPkg == null) return defaultGlow;

    final name = selectedPkg['name']?.toString() ?? '';
    final lower = name.toLowerCase();
    if (lower.contains('titan')) return _tierGlow['Titan'] ?? defaultGlow;
    if (lower.contains('rainmaker')) {
      return _tierGlow['Rainmaker'] ?? defaultGlow;
    }
    // Default to Consultant styling for everything else (Consultant / Free / Silver legacy)
    return _tierGlow['Consultant'] ?? defaultGlow;
  }

  /// True when at least one paid tier exists (coupon applies to paid plans only).
  bool get _showCouponSection {
    return _packages.any((p) {
      final price =
          double.tryParse(p['price_monthly']?.toString() ?? '0') ?? 0;
      return price > 0;
    });
  }

  /// Filter packages to avoid duplicate tier cards. When subscribed, prefer the package matching current tier.
  List<dynamic> get _displayPackages {
    final byTier = <String, dynamic>{};
    for (final pkg in _packages) {
      final name = pkg['name']?.toString() ?? '';
      final normalized = _normalizeTierName(name);
      final isCurrent = _isPremium && name == _currentTier;
      if (byTier[normalized] == null || isCurrent) {
        byTier[normalized] = pkg;
      }
    }
    final result = <dynamic>[];
    final seen = <String>{};
    for (final pkg in _packages) {
      final normalized = _normalizeTierName(pkg['name']?.toString() ?? '');
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        result.add(byTier[normalized]!);
      }
    }
    return result;
  }

  String _durationChipLabel(int months) {
    switch (months) {
      case 1:
        return '1 mo';
      case 3:
        return '3 mo';
      case 6:
        return '6 mo';
      case 12:
        return '1 yr';
      default:
        return '${months}mo';
    }
  }

  String _durationSuffixLabel(int months) {
    switch (months) {
      case 1:
        return '/mo';
      case 3:
        return '/3 mo';
      case 6:
        return '/6 mo';
      case 12:
        return '/yr';
      default:
        return '/$months mo';
    }
  }

  String? _durationBadgeLabel(int months) {
    switch (months) {
      case 3:
        return 'Most Popular';
      case 6:
        return 'Recommended';
      default:
        return null;
    }
  }

  ({List<Color> gradient, IconData icon})? _durationBadgeStyle(int months) {
    switch (months) {
      case 3:
        return (
          gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          icon: Icons.local_fire_department_rounded,
        );
      case 6:
        return (
          gradient: [const Color(0xFF667eea), const Color(0xFF764ba2)],
          icon: Icons.verified_rounded,
        );
      default:
        return null;
    }
  }

  static const _billingAccent = Color(0xFF667eea);

  String _durationTitle(int months) {
    switch (months) {
      case 1:
        return 'Monthly';
      case 3:
        return '3 Months';
      case 6:
        return '6 Months';
      case 12:
        return '1 Year';
      default:
        return '$months Months';
    }
  }

  String? _durationSavingsLabel(int months) {
    switch (months) {
      case 3:
        return '10%';
      case 6:
        return '20%';
      case 12:
        return '30%';
      default:
        return null;
    }
  }

  int _preferredDuration(List<int> available) {
    if (available.contains(3)) return 3;
    if (available.contains(6)) return 6;
    return available.first;
  }

  Widget _buildSectionLabel(String title, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationBadgeChip(int months) {
    final label = _durationBadgeLabel(months);
    final style = _durationBadgeStyle(months);
    if (label != null && style != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: style.gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: style.gradient.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    final savings = _durationSavingsLabel(months);
    if (savings == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$savings OFF',
        style: const TextStyle(
          color: Color(0xFF059669),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _fittedSingleLineText(
    String text, {
    required TextStyle style,
    Alignment alignment = Alignment.center,
    int maxLines = 1,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment == Alignment.center
            ? TextAlign.center
            : alignment == Alignment.centerRight
            ? TextAlign.right
            : TextAlign.left,
        style: style,
      ),
    );
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _couponMessage = 'Enter a coupon code';
        _appliedCoupon = null;
      });
      return;
    }

    if (_selectedPackageId == null) {
      setState(() {
        _couponMessage = 'Select Rainmaker or Titan above, then tap Apply';
        _appliedCoupon = null;
      });
      return;
    }

    final selectedPkg = _packages.firstWhere(
      (p) =>
          (int.tryParse(p['id']?.toString() ?? '') ?? 0) == _selectedPackageId,
      orElse: () => <String, dynamic>{},
    );
    final selectedPrice =
        double.tryParse(selectedPkg['price_monthly']?.toString() ?? '0') ?? 0;
    if (selectedPrice <= 0) {
      setState(() {
        _couponMessage = 'Coupons apply to Rainmaker and Titan plans only';
        _appliedCoupon = null;
      });
      return;
    }

    setState(() {
      _isValidatingCoupon = true;
      _couponMessage = null;
    });

    try {
      final res = await SubscriptionApi.validateCoupon(
        code,
        months: _selectedMonths,
        packageId: _selectedPackageId,
      );
      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final preview = res['preview'] as Map<String, dynamic>?;
        final saved = preview?['discount_amount'];
        setState(() {
          _appliedCoupon = Map<String, dynamic>.from(res['data'] as Map);
          _couponMessage = saved != null
              ? '${_appliedCouponDiscountPercent}% off — saves AED $saved on this plan'
              : '${_appliedCouponDiscountPercent}% off applied to your ${_selectedMonths == 12 ? "1 year" : "$_selectedMonths month"} plan';
        });
      } else {
        setState(() {
          _appliedCoupon = null;
          _couponMessage =
              res['message']?.toString() ?? 'Invalid or expired coupon';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedCoupon = null;
        _couponMessage = 'Could not validate coupon. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _clearCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponMessage = null;
      _couponController.clear();
    });
    IapService().pendingCouponId = null;
  }

  Future<void> _revalidateCouponForSelectedDuration() async {
    if (_appliedCoupon == null) return;
    final code = _appliedCoupon?['code']?.toString() ?? _couponController.text;
    if (code.trim().isEmpty) return;

    try {
      final res = await SubscriptionApi.validateCoupon(
        code,
        months: _selectedMonths,
        packageId: _selectedPackageId,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final preview = res['preview'] as Map<String, dynamic>?;
        final saved = preview?['discount_amount'];
        setState(() {
          _appliedCoupon = Map<String, dynamic>.from(res['data'] as Map);
          _couponMessage = saved != null
              ? '${_appliedCouponDiscountPercent}% off — saves AED $saved on this plan'
              : '${_appliedCouponDiscountPercent}% off applied to your ${_selectedMonths == 12 ? "1 year" : "$_selectedMonths month"} plan';
        });
      } else {
        setState(() {
          _appliedCoupon = null;
          _couponMessage =
              res['message']?.toString() ??
              'Coupon is not valid for this subscription length';
        });
      }
    } catch (_) {
      // Keep previous coupon on transient errors.
    }
  }

  void _onDurationSelected(int months) {
    setState(() => _selectedMonths = months);
    _revalidateCouponForSelectedDuration();
  }

  double _calculatePrice(Map<String, dynamic> pkg) {
    final baseMonthly =
        (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0);

    // Read package-level discount percentages
    double discountPercent = 0.0;
    if (_selectedMonths == 3) {
      discountPercent =
          double.tryParse(pkg['bundle_discount_3_month']?.toString() ?? '') ?? 10.0;
    } else if (_selectedMonths == 6) {
      discountPercent =
          double.tryParse(pkg['bundle_discount_6_month']?.toString() ?? '') ?? 20.0;
    } else if (_selectedMonths == 12) {
      discountPercent =
          double.tryParse(pkg['bundle_discount_12_month']?.toString() ?? '') ?? 30.0;
    }
    final durationDiscountFactor = 1.0 - (discountPercent / 100.0);

    // Calculate monthly price with 2 decimal places
    final monthlyPrice = double.parse((baseMonthly * durationDiscountFactor).toStringAsFixed(2));
    // Calculate total based on 2 decimal monthly price
    double price = double.parse((monthlyPrice * _selectedMonths).toStringAsFixed(2));
    return price;
  }

  double _calculatePriceAfterCoupon(Map<String, dynamic> pkg) {
    final total = _calculatePrice(pkg);
    if (_appliedCoupon == null || _appliedCouponDiscountPercent <= 0) {
      return total;
    }
    return double.parse(
      (total * (1 - _appliedCouponDiscountPercent / 100)).toStringAsFixed(2),
    );
  }

  String _getStorePrice(Map<String, dynamic> pkg) {
    final name = pkg['name']?.toString() ?? '';
    final isFree = (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0) == 0;
    if (isFree) return 'FREE';

    final iapProduct = IapService().findProductForTier(name, _selectedMonths);
    final aedTotal = _calculatePrice(pkg);

    // Mobile stores always charge the SKU list price; coupon affects server ledger only.
    final displayAed =
        (_appliedCoupon != null && !_isMobileIap)
            ? _calculatePriceAfterCoupon(pkg)
            : aedTotal;

    return SubscriptionPricing.displayPrice(
      tierName: name,
      selectedMonths: _selectedMonths,
      aedTotal: displayAed,
      storeProduct: iapProduct,
    );
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                actions: [
                  if (Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.android)
                    TextButton(
                      onPressed: () async {
                        setState(() => _isPurchasing = true);
                        try {
                          // Set up the listener so we can see the result/error
                          IapService().onPurchaseResult = (success, message) async {
                            if (mounted) {
                              setState(() => _isPurchasing = false);
                              if (success) {
                                await ApiClient.clearCache();
                                await _loadData();
                                if (mounted) {
                                  _showSuccessDialog();
                                }
                              } else if (message != null) {
                                // Provide a more helpful message for common store issues
                                String displayMessage = message;
                                if (message.toLowerCase().contains(
                                  'store not available',
                                )) {
                                  displayMessage =
                                      'Payment services are not available on this device (Emulator). Please use a physical phone with a logged-in account.';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(displayMessage),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          };
                          await IapService().restorePurchases();
                        } finally {
                          if (mounted) setState(() => _isPurchasing = false);
                        }
                      },
                      child: const Text(
                        'RESTORE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
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
                                  Expanded(
                                    child: _fittedSingleLineText(
                                      'SUBSCRIPTION',
                                      alignment: Alignment.centerLeft,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ).animate().fadeIn().slideX(begin: -0.1),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (_tierGlow[_currentTier] ??
                                                    const Color(0xFF64748B))
                                                .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              (_tierGlow[_currentTier] ??
                                                      const Color(0xFF64748B))
                                                  .withOpacity(0.3),
                                        ),
                                      ),
                                      child: _fittedSingleLineText(
                                        _currentTier.toUpperCase(),
                                        alignment: Alignment.center,
                                        style: TextStyle(
                                          color:
                                              _tierGlow[_currentTier] ??
                                              const Color(0xFF64748B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                    padding: ResponsiveHelper.contentPadding(context, top: 20),
                    child: ResponsiveHelper.constrainWidth(
                      child: _buildCurrentPlanBanner(isDark),
                    ),
                  ),
                ),

              // Duration Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveHelper.contentPadding(context, top: 20),
                  child: ResponsiveHelper.constrainWidth(
                    child: _buildDurationSelector(isDark),
                  ),
                ),
              ),
              // Package Cards (deduplicated by tier; when subscribed, only one card per tier)
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveHelper.contentPadding(context, top: 8),
                  child: ResponsiveHelper.constrainWidth(
                    child: _buildSectionLabel(
                      'CHOOSE YOUR PLAN',
                      _getGlowForSelectedPackage(),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: ResponsiveHelper.contentPadding(context, top: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final pkg = _displayPackages[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPackageCard(pkg, isDark, index),
                        ),
                      ),
                    );
                  }, childCount: _displayPackages.length),
                ),
              ),

              if (_showCouponSection)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveHelper.contentPadding(context, top: 16),
                    child: ResponsiveHelper.constrainWidth(
                      child: _buildCouponSection(isDark),
                    ),
                  ),
                ),

              // Legal footer with required subscription info
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveHelper.contentPadding(context, top: 40),
                  child: ResponsiveHelper.constrainWidth(
                    child: _buildLegalFooter(isDark),
                  ),
                ),
              ),

              // Bottom spacer - increased to ensure legal text can be scrolled above the purchase bar
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  void _adjustSelectedDuration(int? packageId) {
    if (packageId == null) return;
    final pkg = _packages.firstWhere(
      (p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == packageId,
      orElse: () => null,
    );
    if (pkg != null && pkg['active_durations'] != null) {
      final available = List<int>.from(
        (pkg['active_durations'] as List).map((x) => int.tryParse(x.toString()) ?? 0)
      );
      if (available.isNotEmpty && !available.contains(_selectedMonths)) {
        _selectedMonths = _preferredDuration(available);
      }
    }
  }

  Widget _buildDurationSelector(bool isDark) {
    // Find active package to determine available durations
    final activePkg = _packages.firstWhere(
      (p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == _selectedPackageId,
      orElse: () => _packages.firstWhere(
        (p) => (double.tryParse(p['price_monthly']?.toString() ?? '') ?? 0.0) != 0,
        orElse: () => null,
      ),
    );

    List<int> availableDurations = [1, 3, 6]; // Default fallback
    if (activePkg != null && activePkg['active_durations'] != null) {
      availableDurations = List<int>.from(
        (activePkg['active_durations'] as List).map((x) => int.tryParse(x.toString()) ?? 0)
      );
      availableDurations.sort();
    }

    if (availableDurations.isEmpty) {
      availableDurations = [1];
    }

    // Just in case, if the current selection is invalid, prefer 3-month default
    if (!availableDurations.contains(_selectedMonths)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !availableDurations.contains(_selectedMonths)) {
          setState(() {
            _selectedMonths = _preferredDuration(availableDurations);
          });
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('BILLING PERIOD', _billingAccent),
        const SizedBox(height: 12),
        ...availableDurations.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDurationOption(m, isDark),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04);
  }

  Widget _buildDurationOption(int months, bool isDark) {
    final isSelected = _selectedMonths == months;
    final savings = _durationSavingsLabel(months);
    final title = _durationTitle(months);
    final subtitle = _durationChipLabel(months);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDurationSelected(months),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? _billingAccent.withOpacity(isDark ? 0.18 : 0.07)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? _billingAccent
                  : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: _billingAccent.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _billingAccent : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? _billingAccent
                        : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? _billingAccent
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      savings != null
                          ? 'Save $savings · billed as $subtitle'
                          : 'Billed monthly',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildDurationBadgeChip(months),
            ],
          ),
        ),
      ),
    );
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
    final id = int.tryParse(pkg['id']?.toString() ?? '') ?? 0;
    final priceMonthly =
        double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0;
    final features = (pkg['features'] as List?)?.cast<String>() ?? [];
    final description = pkg['description']?.toString() ?? '';
    final isSelected = _selectedPackageId == id;
    final isCurrentTier = name == _currentTier;
    final isFree = priceMonthly == 0;
    final isComingSoon = _isPackageComingSoon(pkg);

    // Determine if Titan or Rainmaker for special styling
    final isTitan = name.toLowerCase().contains('titan');
    final isRainmaker = name.toLowerCase().contains('rainmaker');
    // Get gradients and glow colors (support both old and new names)
    final gradients =
        _tierGradients[name] ??
        (isTitan ? _tierGradients['Titan'] : null) ??
        (isRainmaker ? _tierGradients['Rainmaker'] : null) ??
        [const Color(0xFF667eea), const Color(0xFF764ba2)];
    final glowColor =
        _tierGlow[name] ??
        (isTitan ? _tierGlow['Titan'] : null) ??
        (isRainmaker ? _tierGlow['Rainmaker'] : null) ??
        const Color(0xFF667eea);

    // Card background color based on tier
    final cardBgColor = isTitan
        ? (isDark ? const Color(0xFF1E293B).withOpacity(0.8) : Colors.white)
        : isRainmaker
        ? (isDark ? const Color(0xFF1E293B).withOpacity(0.8) : Colors.white)
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
              const Color(0xFF6366F1).withOpacity(0.12),
              const Color(0xFF4F46E5).withOpacity(0.05),
            ],
          )
        : null;

    return GestureDetector(
      // Allow selecting the current tier too (so users can renew for 1/6/12 months).
      // Keep "Free" disabled.
      onTap: isFree
          ? null
          : () {
              setState(() {
                _selectedPackageId = isSelected ? null : id;
                _adjustSelectedDuration(isSelected ? null : id);
              });
            },
      child: AnimatedScale(
        scale: isSelected ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
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
            width: isSelected
                ? 2.5
                : (isTitan || isRainmaker)
                ? 1.5
                : 1,
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            displayName.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isTitan
                                  ? const Color(0xFFF59E0B)
                                  : isRainmaker
                                  ? const Color(0xFF6366F1)
                                  : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (isCurrentTier)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
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
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Price — scales down on narrow screens / long INR strings
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isFree)
                        _fittedSingleLineText(
                          'FREE',
                          alignment: Alignment.centerRight,
                          style: TextStyle(
                            color: glowColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else ...[
                        _fittedSingleLineText(
                          isComingSoon ? 'Coming Soon' : _getStorePrice(pkg),
                          alignment: Alignment.centerRight,
                          style: TextStyle(
                            color: isTitan
                                ? const Color(0xFFF59E0B)
                                : isRainmaker
                                ? const Color(0xFF6366F1)
                                : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B)),
                            fontSize: isComingSoon ? 13 : 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!isComingSoon)
                          _fittedSingleLineText(
                            _durationSuffixLabel(_selectedMonths),
                            alignment: Alignment.centerRight,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (isComingSoon && isSelected)
                          _fittedSingleLineText(
                            'Not in store yet',
                            alignment: Alignment.centerRight,
                            maxLines: 2,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
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
            if (!isFree) ...[
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final expDate = _expiresAt != null
                      ? DateTime.tryParse(_expiresAt!)
                      : null;
                  final daysLeft = expDate != null
                      ? expDate.difference(DateTime.now()).inDays
                      : 0;

                  String label = 'SELECT PLAN';
                  if (isCurrentTier) {
                    label =
                        '${daysLeft > 0 ? "$daysLeft DAYS LEFT - " : ""}ADD MORE';
                  } else if (isSelected) {
                    label = '✓ SELECTED';
                  }

                  final isActive = isSelected || isCurrentTier;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(
                              colors: [glowColor, glowColor.withOpacity(0.85)],
                            )
                          : null,
                      color: isActive ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: glowColor,
                        width: isActive ? 0 : 2,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          _fittedSingleLineText(
                            label,
                            style: TextStyle(
                              color: isActive ? Colors.white : glowColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      ),
    ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn().slideY(begin: 0.08);
  }

  Widget _buildPurchaseBar(bool isDark) {
    final pkg = _packages.firstWhere(
      (p) => (int.tryParse(p['id']?.toString() ?? '') ?? 0) == _selectedPackageId,
      orElse: () => <String, dynamic>{},
    );
    if (pkg.isEmpty) return const SizedBox();

    final name = pkg['name']?.toString() ?? 'Plan';
    final durationText = _selectedMonths == 1
        ? '1 month'
        : _selectedMonths == 3
        ? '3 months'
        : _selectedMonths == 6
        ? '6 months'
        : '1 yearly';

    final currentPkgId = int.tryParse(_currentSub?['package_id']?.toString() ?? '');
    final selectedPkgId = int.tryParse(pkg['id']?.toString() ?? '');
    final isRenewing =
        _isPremium && currentPkgId != null && selectedPkgId == currentPkgId;

    // Determine button label based on Upgrade/Downgrade/New/Renew
    final Map<String, int> tierRanks = {
      'Consultant': 1,
      'Rainmaker': 2,
      'Titan': 3,
    };

    final currentTierRank = tierRanks[_currentTier] ?? 0;
    final selectedTierRank = tierRanks[name] ?? 0;

    final isComingSoon = _isPackageComingSoon(pkg);

    String buttonLabel = 'SUBSCRIBE NOW';
    if (isComingSoon) {
      buttonLabel = 'COMING SOON';
    } else if (_paymentMethod == 'razorpay' && _razorpayEnabled && _isMobileIap) {
      buttonLabel = isRenewing ? 'RENEW (RAZORPAY)' : 'PAY WITH RAZORPAY';
    } else if (isRenewing) {
      buttonLabel = 'RENEW NOW';
    } else if (!_isPremium) {
      buttonLabel = 'GET STARTED';
    } else if (selectedTierRank > currentTierRank) {
      buttonLabel = 'UPGRADE NOW';
    } else if (selectedTierRank < currentTierRank) {
      buttonLabel = 'SWITCH PLAN';
    }

    final glowColor = _getGlowForSelectedPackage();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useStackedBar = screenWidth < 380;

    return Material(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: useStackedBar
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPurchaseBarSummary(
                      isDark: isDark,
                      name: name,
                      durationText: durationText,
                      isComingSoon: isComingSoon,
                      pkg: pkg,
                    ),
                    if (_showPaymentMethodPicker) ...[
                      const SizedBox(height: 10),
                      _buildPaymentMethodSelector(isDark),
                    ],
                    const SizedBox(height: 12),
                    _buildPurchaseActionButton(
                      label: buttonLabel,
                      color: glowColor,
                      enabled: !isComingSoon && !_isPurchasing,
                      onPressed: _purchasePackage,
                      fullWidth: true,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPurchaseBarSummary(
                            isDark: isDark,
                            name: name,
                            durationText: durationText,
                            isComingSoon: isComingSoon,
                            pkg: pkg,
                          ),
                          if (_showPaymentMethodPicker) ...[
                            const SizedBox(height: 8),
                            _buildPaymentMethodSelector(isDark),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPurchaseActionButton(
                      label: buttonLabel,
                      color: glowColor,
                      enabled: !isComingSoon && !_isPurchasing,
                      onPressed: _purchasePackage,
                      fullWidth: false,
                    ),
                  ],
                ),
        ),
      ),
    ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildPaymentMethodSelector(bool isDark) {
    final storeLabel = _isIos ? 'App Store' : 'Google Play';

    Widget chip(String value, String label, IconData icon) {
      final selected = _paymentMethod == value;
      return Expanded(
        child: GestureDetector(
          onTap: _isPurchasing
              ? null
              : () => setState(() => _paymentMethod = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF6366F1).withOpacity(0.18)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF818CF8)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? (isDark ? Colors.white : const Color(0xFF1E293B))
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (_iapEnabledForPlatform) ...[
          chip('iap', storeLabel, Icons.shop_rounded),
          if (_razorpayEnabled) const SizedBox(width: 8),
        ],
        if (_razorpayEnabled)
          chip('razorpay', 'Razorpay', Icons.account_balance_wallet_outlined),
      ],
    );
  }

  Widget _buildPurchaseActionButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
    required bool fullWidth,
  }) {
    final child = Material(
      color: enabled ? color : color.withOpacity(0.45),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fullWidth ? 16 : 22,
            vertical: 14,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: child);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 168),
      child: child,
    );
  }

  Widget _buildCouponSection(bool isDark) {
    Map<String, dynamic> pkg = {};
    if (_selectedPackageId != null) {
      pkg = Map<String, dynamic>.from(
        _packages.firstWhere(
          (p) =>
              (int.tryParse(p['id']?.toString() ?? '') ?? 0) ==
              _selectedPackageId,
          orElse: () => <String, dynamic>{},
        ),
      );
    }
    final isFreeSelected = pkg.isNotEmpty &&
        (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0) == 0;
    final needsPlanSelection = _selectedPackageId == null || pkg.isEmpty;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Have a coupon?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (needsPlanSelection) ...[
            const SizedBox(height: 6),
            Text(
              'Select Rainmaker or Titan above, then enter your code.',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ] else if (isFreeSelected) ...[
            const SizedBox(height: 6),
            Text(
              'Coupons apply to Rainmaker and Titan plans only.',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  enabled: !_isValidatingCoupon &&
                      _appliedCoupon == null &&
                      !isFreeSelected,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _applyCoupon(),
                ),
              ),
              const SizedBox(width: 8),
              if (_appliedCoupon != null)
                TextButton(
                  onPressed: _clearCoupon,
                  child: const Text('Remove'),
                )
              else
                FilledButton(
                  onPressed: _isValidatingCoupon ? null : _applyCoupon,
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
            ],
          ),
          if (_couponMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _couponMessage!,
              style: TextStyle(
                color: _appliedCoupon != null
                    ? const Color(0xFF10B981)
                    : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_appliedCoupon != null && _isMobileIap) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_mobileStoreName will charge the full listed price at checkout. '
                      'Your $_appliedCouponDiscountPercent% coupon is applied on RealtorOne when the subscription activates (you will see the discounted amount in your account).',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchaseBarSummary({
    required bool isDark,
    required String name,
    required String durationText,
    required bool isComingSoon,
    required Map<String, dynamic> pkg,
  }) {
    final hasCoupon = _appliedCoupon != null && !isComingSoon;
    final storePrice = _storeListedPrice(pkg);
    final originalAed = _calculatePrice(pkg);
    final discountedAed = _calculatePriceAfterCoupon(pkg);
    final showIapCouponSplit = hasCoupon && _isMobileIap && storePrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$name · $durationText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (showIapCouponSplit) ...[
          _fittedSingleLineText(
            storePrice,
            alignment: Alignment.centerLeft,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$_mobileStoreName charge',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _fittedSingleLineText(
            SubscriptionPricing.formatAedTotal(discountedAed),
            alignment: Alignment.centerLeft,
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'After $_appliedCouponDiscountPercent% coupon (on activation)',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          if (hasCoupon) ...[
            _fittedSingleLineText(
              SubscriptionPricing.formatAedTotal(originalAed),
              alignment: Alignment.centerLeft,
              style: TextStyle(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
          ],
          _fittedSingleLineText(
            isComingSoon
                ? 'Coming Soon'
                : (hasCoupon
                      ? SubscriptionPricing.formatAedTotal(discountedAed)
                      : _getStorePrice(pkg)),
            alignment: Alignment.centerLeft,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: isComingSoon ? 18 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasCoupon)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_appliedCouponDiscountPercent}% coupon applied',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildLegalFooter(bool isDark) {
    return Column(
      children: [
        const Text(
          'Subscription Information',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '• Title: RealtorOne Premium (Consultant, Rainmaker, or Titan tiers)\n'
            '• Length: 1 Month, 3 Months, 6 Months, or 1 Year (auto-renewable)\n'
            '• Price: Google Play / App Store shows the product list price. Coupons adjust your RealtorOne subscription ledger after activation.\n'
            '• Test builds: Play may show "/5 min" — that is a sandbox renewal interval, not production billing.\n\n'
            'Payment will be charged to your iTunes Account (for iOS) or Google Play Account (for Android) at confirmation of purchase. '
            'Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. '
            'Account will be charged for renewal within 24-hours prior to the end of the current period. '
            'Subscriptions may be managed and auto-renewal may be turned off by going to your App Store or Play Store Account Settings after purchase.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegalLink('Terms of Use (EULA)', 'terms'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 12,
              width: 1,
              color: const Color(0xFF64748B).withOpacity(0.3),
            ),
            _buildLegalLink('Privacy Policy', 'privacy'),
          ],
        ),
        const SizedBox(height: 30), // Extra space at the very bottom
      ],
    );
  }

  Widget _buildLegalLink(String label, String slug) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LegalDocumentWebViewPage(slug: slug),
          ),
        );
      },
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF667eea),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
