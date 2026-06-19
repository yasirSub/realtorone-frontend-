// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/app_config.dart';
import '../../api/subscription_api.dart';
import '../../api/api_client.dart';
import '../../services/iap_service.dart';
import '../../services/meta_app_events_service.dart';
import '../../services/razorpay_service.dart';
import '../../widgets/elite_loader.dart';
import '../../utils/responsive_helper.dart';
import '../../api/user_api.dart';
import '../../utils/phone_utils.dart';
import '../../utils/subscription_pricing.dart';
import '../../utils/api_user_message.dart';
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
  bool _razorpayEligibleForUser = false;
  bool _appleIapEnabled = true;
  bool _googleIapEnabled = true;
  String _paymentMethod = 'iap';

  double? _serverAedToInrRate;
  Map<String, dynamic>? _pricingQuote;
  bool _pricingQuoteLoading = false;

  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  String? _couponMessage;
  bool _isValidatingCoupon = false;

  bool get _isIos => Theme.of(context).platform == TargetPlatform.iOS;

  bool get _iapEnabledForPlatform =>
      _isIos ? _appleIapEnabled : _googleIapEnabled;

  bool get _razorpayAvailable => _razorpayEnabled && _razorpayEligibleForUser;

  bool get _usingRazorpayCheckout =>
      _paymentMethod == 'razorpay' && _razorpayAvailable;

  bool get _showPaymentMethodPicker =>
      _isMobileIap && _razorpayAvailable && _iapEnabledForPlatform;

  /// India / INR store: show converted ₹ prices only (hide AED list price).
  bool get _showInrConvertedPrice =>
      _razorpayEligibleForUser || SubscriptionPricing.useIndianRupee;

  String _formatLedgerAmount(double aedAmount) {
    if (_showInrConvertedPrice) {
      return SubscriptionPricing.formatInrLabel(_inrChargeFromAed(aedAmount));
    }
    return SubscriptionPricing.formatAedLabel(aedAmount);
  }

  String _formatDisplayTotal(double aedAmount) {
    if (_showInrConvertedPrice) {
      return SubscriptionPricing.formatInrLabel(_inrChargeFromAed(aedAmount));
    }
    return SubscriptionPricing.formatAedTotal(
      aedAmount,
      inrRate: _serverAedToInrRate,
    );
  }

  String _couponSavingsMessage(num? savedAed) {
    if (savedAed == null) {
      return '${_appliedCouponDiscountPercent}% off applied to your ${_selectedMonths == 12 ? "1 year" : "$_selectedMonths month"} plan';
    }
    if (_showInrConvertedPrice) {
      final savedInr = _inrChargeFromAed(savedAed.toDouble());
      return '${_appliedCouponDiscountPercent}% off — saves ${SubscriptionPricing.formatInrLabel(savedInr)} on this plan';
    }
    return '${_appliedCouponDiscountPercent}% off — saves AED $savedAed on this plan';
  }

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
        UserApi.getProfile(useCache: false),
      ]);

      final packagesRes = results[0] as Map<String, dynamic>;
      final subRes = results[1] as Map<String, dynamic>;
      final rzRes = results[3] as Map<String, dynamic>;
      final profileRes = results[4] as Map<String, dynamic>;

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
          _razorpayEligibleForUser = rzRes['razorpay_eligible_for_user'] == true;
          final paySettings = rzRes['payment_settings'];
          if (paySettings is Map) {
            _appleIapEnabled = paySettings['apple_iap_enabled'] != false;
            _googleIapEnabled = paySettings['google_iap_enabled'] != false;
            final serverRazorpayOn = paySettings['razorpay_enabled'] == true;
            _razorpayEnabled = serverRazorpayOn;
            final rate = paySettings['aed_to_inr_rate'];
            if (rate is num) {
              _serverAedToInrRate = rate.toDouble();
            }
          }
          final rzRate = rzRes['aed_to_inr_rate'];
          if (rzRate is num) {
            _serverAedToInrRate = rzRate.toDouble();
          }
          if (profileRes['success'] == true && profileRes['data'] is Map) {
            final mobile = profileRes['data']['mobile']?.toString();
            _razorpayEligibleForUser = PhoneUtils.isIndiaMobile(mobile);
          }
          if (_isMobileIap) {
            if (!_iapEnabledForPlatform && _razorpayAvailable) {
              _paymentMethod = 'razorpay';
            } else if (_iapEnabledForPlatform && !_razorpayAvailable) {
              _paymentMethod = 'iap';
            } else if (_paymentMethod == 'razorpay' && !_razorpayAvailable) {
              _paymentMethod = 'iap';
            }
          }
          _isLoading = false;
        });
        if ((_showInrConvertedPrice || _razorpayAvailable) &&
            _selectedPackageId != null) {
          await _refreshPricingQuote();
        }
      }
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPricingQuote() async {
    if (_selectedPackageId == null) {
      if (mounted) setState(() => _pricingQuote = null);
      return;
    }

    setState(() => _pricingQuoteLoading = true);
    try {
      final res = await SubscriptionApi.getPricingQuote(
        packageId: _selectedPackageId!,
        months: _selectedMonths,
        couponId: _appliedCouponId,
        countryCode: SubscriptionPricing.deviceCountryCode(),
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final rate = data['aed_to_inr_rate'];
        setState(() {
          _pricingQuote = data;
          if (rate is num) {
            _serverAedToInrRate = rate.toDouble();
          }
        });
      } else {
        setState(() => _pricingQuote = null);
      }
    } catch (e) {
      debugPrint('Pricing quote failed: $e');
      if (mounted) setState(() => _pricingQuote = null);
    } finally {
      if (mounted) setState(() => _pricingQuoteLoading = false);
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

    if (isMobile && _paymentMethod == 'razorpay' && _razorpayAvailable) {
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
              String displayMessage = ApiUserMessage.sanitize(
                message,
                fallback: 'Payment could not be completed. Please try again.',
              );
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

    if (kIsWeb && _razorpayAvailable) {
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
      final iapProduct = _iapProductForPackage(pkg);
      final orderRes = await SubscriptionApi.createRazorpayOrder(
        packageId: _selectedPackageId!,
        months: _selectedMonths,
        couponId: _appliedCouponId,
        iapProductId: _appliedCouponId == null ? iapProduct?.id : null,
        iapAmountPaise: _appliedCouponId == null
            ? SubscriptionPricing.iapAmountPaise(iapProduct)
            : null,
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
          final pricing = verify['pricing'];
          final parsed = MetaAppEventsService.pricingFromActivation(
            pricing is Map ? Map<String, dynamic>.from(pricing) : null,
          );
          if (parsed != null) {
            await MetaAppEventsService.instance.trackSubscriptionPurchase(
              orderId: paymentId,
              amount: parsed.amount,
              currency: parsed.currency,
              contentId: _selectedPackageId?.toString(),
              numItems: 1,
            );
          } else {
            await MetaAppEventsService.instance.trackSubscriptionPurchase(
              orderId: paymentId,
              amount: amount / 100,
              currency: data['currency']?.toString() ?? 'INR',
              contentId: _selectedPackageId?.toString(),
              numItems: 1,
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
          final safe = ApiUserMessage.sanitize(
            message,
            fallback: 'Payment could not be completed. Please try again.',
          );
          if (safe.toLowerCase().contains('cancel')) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(safe),
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
            content: Text(
              ApiUserMessage.sanitize(
                e.toString().replaceFirst('Exception: ', ''),
                fallback: 'Could not start payment. Please try again.',
              ),
            ),
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

  /// Clarifies that card price is the total for the selected billing period.
  String _durationPriceContextLabel(int months) {
    switch (months) {
      case 1:
        return 'per month';
      case 3:
        return 'for 3 months';
      case 6:
        return 'for 6 months';
      case 12:
        return 'for 1 year';
      default:
        return 'for $months months';
    }
  }

  String _durationPlanBadgeLabel(int months) {
    switch (months) {
      case 1:
        return 'MONTHLY';
      case 3:
        return '3-MONTH';
      case 6:
        return '6-MONTH';
      case 12:
        return 'YEARLY';
      default:
        return '${months}M';
    }
  }

  String? _effectiveMonthlyPriceLine(Map<String, dynamic> pkg) {
    if (_selectedMonths <= 1) return null;
    if (_isPackageComingSoon(pkg)) return null;
    final isFree =
        (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0) == 0;
    if (isFree) return null;

    if (_showInrConvertedPrice) {
      final inr = _getDisplayInrAmount(pkg);
      if (inr != null) {
        return '≈ ${SubscriptionPricing.formatInrLabel(inr / _selectedMonths)}/mo';
      }
    }

    final total = _calculatePrice(pkg);
    return '≈ ${_formatLedgerAmount(total / _selectedMonths)}/mo';
  }

  Widget _buildBillingPeriodBadge({
    required int months,
    required Color accent,
    required bool isDark,
    bool compact = false,
  }) {
    final savings = _durationSavingsLabel(months);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: accent.withOpacity(isDark ? 0.22 : 0.1),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              months == 1
                  ? Icons.calendar_today_rounded
                  : Icons.event_repeat_rounded,
              size: compact ? 10 : 12,
              color: accent,
            ),
            const SizedBox(width: 3),
            Text(
              _durationPlanBadgeLabel(months),
              style: TextStyle(
                color: accent,
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            if (savings != null && !compact) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '-$savings',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
              ? _couponSavingsMessage(
                  saved is num
                      ? saved.toDouble()
                      : double.tryParse(saved.toString()),
                )
              : _couponSavingsMessage(null);
        });
        await _refreshPricingQuote();
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
    _refreshPricingQuote();
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
              ? _couponSavingsMessage(
                  saved is num
                      ? saved.toDouble()
                      : double.tryParse(saved.toString()),
                )
              : _couponSavingsMessage(null);
        });
        await _refreshPricingQuote();
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
    _refreshPricingQuote();
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

    // Match backend SubscriptionActivationService::pricingBreakdown (whole-AED monthly).
    final monthlyPrice = (baseMonthly * durationDiscountFactor).roundToDouble();
    return monthlyPrice * _selectedMonths;
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

  double _inrChargeFromAed(double amountAed) {
    final rate = _serverAedToInrRate ?? SubscriptionPricing.aedToInrRate;
    return SubscriptionPricing.inrChargeFromAed(amountAed, rate);
  }

  ProductDetails? _iapProductForPackage(Map<String, dynamic> pkg) {
    final tierName = _normalizeTierName(pkg['name']?.toString() ?? '');
    return IapService().findProductForTier(tierName, _selectedMonths);
  }

  /// INR amount for display/checkout — Play SKU, server quote, or AED×rate.
  double? _getDisplayInrAmount(Map<String, dynamic> pkg) {
    if (_appliedCoupon == null) {
      final storeInr = SubscriptionPricing.iapInrAmount(_iapProductForPackage(pkg));
      if (storeInr != null) return storeInr;
    }

    final selectedId = int.tryParse(pkg['id']?.toString() ?? '');
    if (selectedId == _selectedPackageId &&
        _pricingQuote != null &&
        (_pricingQuote!['amount_inr'] is num)) {
      return (_pricingQuote!['amount_inr'] as num).toDouble();
    }

    final aed = _appliedCoupon != null
        ? _calculatePriceAfterCoupon(pkg)
        : _calculatePrice(pkg);
    return _inrChargeFromAed(aed);
  }

  double? _razorpayInrAmount(Map<String, dynamic> pkg) =>
      _getDisplayInrAmount(pkg);

  String _getStorePrice(Map<String, dynamic> pkg) {
    final name = pkg['name']?.toString() ?? '';
    final isFree = (double.tryParse(pkg['price_monthly']?.toString() ?? '0') ?? 0) == 0;
    if (isFree) return 'FREE';

    final aedTotal = _calculatePrice(pkg);

    // India: show converted ₹ only — no AED list price on cards.
    if (_showInrConvertedPrice || _usingRazorpayCheckout) {
      final inr = _getDisplayInrAmount(pkg);
      if (inr != null) {
        return SubscriptionPricing.formatInrLabel(inr);
      }
    }

    final iapProduct = IapService().findProductForTier(name, _selectedMonths);

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
      inrRate: _serverAedToInrRate,
      preferAed: !_showInrConvertedPrice,
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
        _buildSectionLabel('CHOOSE BILLING PERIOD', _billingAccent),
        const SizedBox(height: 4),
        Text(
          'Pick how long you want to subscribe — prices update on each plan below.',
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < availableDurations.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _buildDurationPill(
                  availableDurations[i],
                  isDark,
                ),
              ),
            ],
          ],
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04);
  }

  String _durationNumberLabel(int months) {
    switch (months) {
      case 12:
        return '1';
      default:
        return '$months';
    }
  }

  String _durationUnitLabel(int months) {
    switch (months) {
      case 1:
        return 'MONTH';
      case 12:
        return 'YEAR';
      default:
        return 'MONTHS';
    }
  }

  Widget _buildDurationPill(int months, bool isDark) {
    final isSelected = _selectedMonths == months;
    final savings = _durationSavingsLabel(months);
    final badgeStyle = _durationBadgeStyle(months);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDurationSelected(months),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _billingAccent.withOpacity(isDark ? 0.35 : 0.14),
                      _billingAccent.withOpacity(isDark ? 0.18 : 0.06),
                    ],
                  )
                : null,
            color: isSelected
                ? null
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
                  color: _billingAccent.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeStyle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(
                    badgeStyle.icon,
                    size: 14,
                    color: badgeStyle.gradient.first,
                  ),
                )
              else
                const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _durationNumberLabel(months),
                  style: TextStyle(
                    color: isSelected
                        ? _billingAccent
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _durationUnitLabel(months),
                  style: TextStyle(
                    color: isSelected
                        ? _billingAccent.withOpacity(0.85)
                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (savings != null) ...[
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(
                        isSelected ? 0.18 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SAVE $savings',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
              ],
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
              _refreshPricingQuote();
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
                            fontSize: isComingSoon ? 13 : 22,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        if (!isComingSoon) ...[
                          const SizedBox(height: 4),
                          _fittedSingleLineText(
                            _durationPriceContextLabel(_selectedMonths),
                            alignment: Alignment.centerRight,
                            style: TextStyle(
                              color: glowColor.withOpacity(0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_effectiveMonthlyPriceLine(pkg) != null) ...[
                            const SizedBox(height: 2),
                            _fittedSingleLineText(
                              _effectiveMonthlyPriceLine(pkg)!,
                              alignment: Alignment.centerRight,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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

    String buttonLabel = 'Subscribe';
    String? buttonSubLabel;
    if (isComingSoon) {
      buttonLabel = 'Coming soon';
    } else if (_paymentMethod == 'razorpay' && _razorpayAvailable && _isMobileIap) {
      buttonLabel = isRenewing ? 'Renew plan' : 'Pay now';
      buttonSubLabel = 'Razorpay · UPI & cards';
    } else if (isRenewing) {
      buttonLabel = 'Renew plan';
    } else if (!_isPremium) {
      buttonLabel = 'Get started';
    } else if (selectedTierRank > currentTierRank) {
      buttonLabel = 'Upgrade';
    } else if (selectedTierRank < currentTierRank) {
      buttonLabel = 'Switch plan';
    }

    final glowColor = _getGlowForSelectedPackage();
    final displayName = name
        .replaceAll(' - GOLD', '')
        .replaceAll('- GOLD', '')
        .replaceAll(' GOLD', '')
        .replaceAll('GOLD', '')
        .trim();

    return Material(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPurchaseBarSummary(
                isDark: isDark,
                name: displayName,
                isComingSoon: isComingSoon,
                pkg: pkg,
                accent: glowColor,
              ),
              if (_showPaymentMethodPicker) ...[
                const SizedBox(height: 10),
                _buildPaymentMethodSelector(isDark),
              ],
              const SizedBox(height: 12),
              _buildPurchaseActionButton(
                label: buttonLabel,
                subLabel: buttonSubLabel,
                color: glowColor,
                enabled: !isComingSoon && !_isPurchasing,
                onPressed: _purchasePackage,
                isLoading: _isPurchasing,
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
              : () {
                  setState(() => _paymentMethod = value);
                  _refreshPricingQuote();
                },
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
          if (_razorpayAvailable) const SizedBox(width: 8),
        ],
        if (_razorpayAvailable)
          chip('razorpay', 'Razorpay (IN)', Icons.account_balance_wallet_outlined),
      ],
    );
  }

  Widget _buildPurchaseActionButton({
    required String label,
    String? subLabel,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: enabled ? color : color.withOpacity(0.45),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: enabled ? 4 : 0,
      shadowColor: color.withOpacity(0.35),
      child: InkWell(
        onTap: enabled && !isLoading ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
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
          if (_appliedCoupon != null && _isMobileIap && !_usingRazorpayCheckout) ...[
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
    required bool isComingSoon,
    required Map<String, dynamic> pkg,
    required Color accent,
  }) {
    final hasCoupon = _appliedCoupon != null && !isComingSoon;
    final storePrice = _storeListedPrice(pkg);
    final discountedAed = _calculatePriceAfterCoupon(pkg);
    final showIapCouponSplit =
        hasCoupon &&
        _isMobileIap &&
        !_usingRazorpayCheckout &&
        storePrice != null &&
        !_showInrConvertedPrice;

    String mainPrice() {
      if (_pricingQuoteLoading && (_usingRazorpayCheckout || _showInrConvertedPrice)) {
        return '…';
      }
      if (isComingSoon) return 'Coming soon';
      if (_usingRazorpayCheckout) {
        final inr = _razorpayInrAmount(pkg);
        if (inr != null) return SubscriptionPricing.formatInrLabel(inr);
        return '…';
      }
      if (hasCoupon) return _formatDisplayTotal(discountedAed);
      return _getStorePrice(pkg);
    }

    final monthlyLine = _effectiveMonthlyPriceLine(pkg);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildBillingPeriodBadge(
                      months: _selectedMonths,
                      accent: accent,
                      isDark: isDark,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _fittedSingleLineText(
                    mainPrice(),
                    alignment: Alignment.centerRight,
                    style: TextStyle(
                      color: accent,
                      fontSize: isComingSoon ? 14 : 24,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  if (!isComingSoon && monthlyLine != null) ...[
                    const SizedBox(height: 2),
                    _fittedSingleLineText(
                      monthlyLine,
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (showIapCouponSplit) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 8),
            Text(
              'Store charge: $storePrice',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'After coupon: ${_formatDisplayTotal(discountedAed)} (on activation)',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (hasCoupon) ...[
            const SizedBox(height: 8),
            Text(
              '${_appliedCouponDiscountPercent}% coupon applied',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegalFooter(bool isDark) {
    final usingRazorpay = _paymentMethod == 'razorpay' && _razorpayAvailable;
    final body = usingRazorpay
        ? '• Title: RealtorOne Premium (Consultant, Rainmaker, or Titan tiers)\n'
            '• Length: 1 Month, 3 Months, 6 Months, or 1 Year\n'
            '• Price: Shown in INR (₹) and charged via Razorpay at checkout.\n'
            '• Region: Razorpay checkout is for India (+91) numbers — UPI and cards.\n\n'
            'Payment is processed by Razorpay. Your subscription period starts after successful payment verification. '
            'This is not an auto-renewing App Store or Google Play subscription.'
        : (_showInrConvertedPrice
              ? '• Title: RealtorOne Premium (Consultant, Rainmaker, or Titan tiers)\n'
                  '• Length: 1 Month, 3 Months, 6 Months, or 1 Year (auto-renewable)\n'
                  '• Price: Shown in INR (₹) — $_mobileStoreName charges the store price in rupees.\n'
                  '• Coupons adjust your RealtorOne subscription ledger after activation.\n\n'
                  'Payment will be charged to your $_mobileStoreName account at confirmation of purchase.'
              : '• Title: RealtorOne Premium (Consultant, Rainmaker, or Titan tiers)\n'
                  '• Length: 1 Month, 3 Months, 6 Months, or 1 Year (auto-renewable)\n'
                  '• Price: $_mobileStoreName shows the product list price. Coupons adjust your RealtorOne subscription ledger after activation.\n'
                  '• Test builds: Play may show "/5 min" — that is a sandbox renewal interval, not production billing.\n\n'
                  'Payment will be charged to your iTunes Account (for iOS) or Google Play Account (for Android) at confirmation of purchase. '
                  'Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. '
                  'Account will be charged for renewal within 24-hours prior to the end of the current period. '
                  'Subscriptions may be managed and auto-renewal may be turned off by going to your App Store or Play Store Account Settings after purchase.');

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
            body,
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
