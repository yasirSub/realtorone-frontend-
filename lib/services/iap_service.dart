import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../api/subscription_api.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool isAvailable = false;
  List<ProductDetails> products = [];
  
  // Callbacks for the UI to show success/failure
  Function(bool success, String? message)? onPurchaseResult;

  /// Maps backend tier names to Apple/Google product ID prefixes.
  /// These MUST match exactly what you create in App Store Connect / Google Play Console.
  static const Map<String, String> _tierProductPrefix = {
    'consultant': 'consultant',
    'rainmaker': 'rainmaker',
    'titan': 'titan',
  };

  /// Maps duration months to Apple/Google product ID suffixes.
  static const Map<int, String> _durationSuffix = {
    1: '1_month',
    3: '3_months',
    6: '6_months',
    12: '12_months',
  };

  /// All possible product IDs to pre-fetch from the store.
  static Set<String> get allProductIds {
    final ids = <String>{};
    for (final tier in _tierProductPrefix.values) {
      for (final duration in _durationSuffix.values) {
        ids.add('com.realtorone.app.${tier}_$duration');
      }
    }
    return ids;
  }

  void initialize() {
    if (kIsWeb) return;
    
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP stream error: $error');
    });
    
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('IAP not available on this device/platform.');
      return;
    }
    // Pre-fetch all products so they're ready when the user taps "Buy"
    await fetchProducts(allProductIds);
  }

  /// Builds the Apple/Google product ID from tier name and months.
  /// Example: "Titan" + 1 month → "titan_1_month"
  String getProductId(String tierName, int months) {
    final normalizedTier = tierName
        .toLowerCase()
        .replaceAll(' - gold', '')
        .replaceAll('-gold', '')
        .replaceAll(' gold', '')
        .trim();
    final prefix = _tierProductPrefix[normalizedTier] ?? normalizedTier;
    final suffix = _durationSuffix[months] ?? '${months}_months';
    return 'com.realtorone.app.${prefix}_$suffix';
  }

  /// Legacy method: builds product ID from package ID (for backward compatibility)
  String getProductIdFromPackageId(int packageId, int months) {
    return 'com.realtorone.tier_${packageId}_${months}m';
  }

  Future<List<ProductDetails>> fetchProducts(Set<String> productIds) async {
    if (!isAvailable) return [];
    final response = await _inAppPurchase.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('Error fetching products: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found in store: ${response.notFoundIDs}');
    }
    products = response.productDetails;
    debugPrint('Fetched ${products.length} products from store');
    return products;
  }

  /// Purchase a subscription by tier name and duration.
  /// [tierName] - e.g. "Titan", "Rainmaker", "Consultant"
  /// [months] - 1, 3, 6, or 12
  /// [packageId] - backend package ID for verification
  Future<void> buyByTier(String tierName, int months, int packageId) async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available on this device.');
      return;
    }

    final productId = getProductId(tierName, months);
    debugPrint('Attempting to buy product: $productId');
    
    // Check if we already fetched it
    ProductDetails? product = products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );

    if (product == null) {
      // Try to fetch it on demand
      final fetched = await fetchProducts({productId});
      if (fetched.isNotEmpty) {
        product = fetched.first;
      }
    }

    if (product == null) {
      onPurchaseResult?.call(
        false, 
        'This plan is currently unavailable in the App Store. Please try again later.',
      );
      debugPrint('Product not found in store: $productId');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      // Subscriptions use buyNonConsumable
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseResult?.call(false, 'Failed to initiate purchase: $e');
    }
  }

  /// Legacy method: buy by packageId (kept for backward compatibility)
  Future<void> buyPackage(int packageId, int months) async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available');
      return;
    }

    final productId = getProductIdFromPackageId(packageId, months);
    
    // Check if we already fetched it
    ProductDetails? product = products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );

    if (product == null) {
      // Try to fetch it on demand
      final fetched = await fetchProducts({productId});
      if (fetched.isNotEmpty) {
        product = fetched.first;
      }
    }

    if (product == null) {
      onPurchaseResult?.call(false, 'This plan is currently unavailable in the App Store. Please try again later.');
      debugPrint('Product not found: $productId');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseResult?.call(false, 'Failed to initiate purchase: $e');
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // UI can show a loader
        debugPrint('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
          onPurchaseResult?.call(false, purchaseDetails.error?.message ?? 'Purchase failed');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          debugPrint('Purchase successful! ID: ${purchaseDetails.purchaseID}');
          
          // Verify with backend
          await _verifyPurchaseWithBackend(purchaseDetails);
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    // Parse product ID to extract tier and months
    // Format: {tier}_{duration} e.g. "titan_1_month", "rainmaker_3_months"
    final productId = purchase.productID;
    
    // Try new format first: tier_N_month(s)
    int? packageId;
    int months = 1;
    
    // Map tier name back to a backend package ID
    // We'll let the backend figure out the package from the tier name
    final tierMonthsMap = _parseTierProduct(productId);
    if (tierMonthsMap != null) {
      months = tierMonthsMap['months'] as int;
      // Send tier name to backend, let it resolve the package
      try {
        final res = await SubscriptionApi.purchaseSubscriptionByTier(
          tierName: tierMonthsMap['tier'] as String,
          months: months,
          paymentId: purchase.purchaseID ?? 'APPLE_${DateTime.now().millisecondsSinceEpoch}',
          receipt: Platform.isIOS 
              ? purchase.verificationData.serverVerificationData 
              : null,
        );
        if (res['success'] == true) {
          onPurchaseResult?.call(true, null);
        } else {
          onPurchaseResult?.call(false, res['message'] ?? 'Backend validation failed');
        }
        return;
      } catch (e) {
        debugPrint('Tier-based purchase verification failed: $e');
      }
    }
    
    // Fallback: try legacy format com.realtorone.tier_{packageId}_{months}m
    final parts = productId.split('_');
    if (parts.length >= 3) {
      try {
        packageId = int.parse(parts[1]);
        final monthsStr = parts[2].replaceAll('m', '');
        months = int.parse(monthsStr);

        final res = await SubscriptionApi.purchaseSubscription(
          packageId: packageId,
          months: months,
          paymentId: purchase.purchaseID ?? 'APPLE_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (res['success'] == true) {
          onPurchaseResult?.call(true, null);
        } else {
          onPurchaseResult?.call(false, res['message'] ?? 'Backend validation failed');
        }
      } catch (e) {
        onPurchaseResult?.call(false, 'Failed to verify purchase with backend: $e');
      }
    } else {
      onPurchaseResult?.call(false, 'Unknown product ID format: ${purchase.productID}');
    }
  }

  /// Parses a product ID like "com.realtorone.app.titan_1_month" into tier name and months.
  Map<String, dynamic>? _parseTierProduct(String productId) {
    // Strip package prefix if present
    final cleanId = productId.replaceFirst('com.realtorone.app.', '');
    
    for (final entry in _tierProductPrefix.entries) {
      if (cleanId.startsWith(entry.value)) {
        for (final durEntry in _durationSuffix.entries) {
          if (cleanId == '${entry.value}_${durEntry.value}') {
            return {
              'tier': entry.key[0].toUpperCase() + entry.key.substring(1), // Capitalize
              'months': durEntry.key,
            };
          }
        }
      }
    }
    return null;
  }

  Future<void> restorePurchases() async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available on this device.');
      return;
    }
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Restore error: $e');
      onPurchaseResult?.call(false, 'Failed to restore purchases: $e');
    }
  }

  void dispose() {
    if (!kIsWeb) {
      _subscription.cancel();
    }
  }
}
