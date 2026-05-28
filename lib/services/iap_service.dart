import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../api/api_client.dart';
import '../api/subscription_api.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool isAvailable = false;
  List<ProductDetails> products = [];
  final Set<String> _lastNotFoundIds = <String>{};

  /// Callbacks for the UI to show success/failure
  Function(bool success, String? message)? onPurchaseResult;

  String? _lastBackendError;

  /// Maps backend tier names to Apple/Google product ID prefixes.
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
        final shortId = '${tier}_$duration';
        ids.add('com.realtorone.app.$shortId');
        // Some App Store Connect setups use short product IDs (without bundle prefix).
        // Keep this fallback for iOS only; Android flow remains unchanged.
        if (Platform.isIOS) {
          ids.add(shortId);
        }
      }
    }
    return ids;
  }

  void initialize() {
    if (kIsWeb) return;

    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('IAP stream error: $error');
      },
    );

    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('IAP not available on this device/platform.');
      return;
    }
    await fetchProducts(allProductIds);
  }

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

  Set<String> getProductIdCandidates(String tierName, int months) {
    final normalizedTier = tierName
        .toLowerCase()
        .replaceAll(' - gold', '')
        .replaceAll('-gold', '')
        .replaceAll(' gold', '')
        .trim();
    final prefix = _tierProductPrefix[normalizedTier] ?? normalizedTier;
    final suffix = _durationSuffix[months] ?? '${months}_months';
    final shortId = '${prefix}_$suffix';

    return {
      'com.realtorone.app.$shortId',
      if (Platform.isIOS) shortId,
    };
  }

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
      _lastNotFoundIds.addAll(response.notFoundIDs);
    }
    products = response.productDetails;
    for (final p in products) {
      _lastNotFoundIds.remove(p.id);
    }
    debugPrint('Fetched ${products.length} products from store');
    return products;
  }

  bool hasProduct(String productId) {
    return products.any((p) => p.id == productId);
  }

  bool hasAnyProductForTierDuration(String tierName, int months) {
    final candidates = getProductIdCandidates(tierName, months);
    return products.any((p) => candidates.contains(p.id));
  }

  Set<String> get lastNotFoundIds => Set.unmodifiable(_lastNotFoundIds);

  Future<void> buyByTier(String tierName, int months, int packageId) async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available on this device.');
      return;
    }

    final candidateIds = getProductIdCandidates(tierName, months);
    debugPrint('Attempting to buy product from candidates: $candidateIds');

    ProductDetails? product = products.cast<ProductDetails?>().firstWhere(
      (p) => p != null && candidateIds.contains(p.id),
      orElse: () => null,
    );

    if (product == null) {
      final fetched = await fetchProducts(candidateIds);
      if (fetched.isNotEmpty) {
        product = fetched.cast<ProductDetails?>().firstWhere(
          (p) => p != null && candidateIds.contains(p.id),
          orElse: () => null,
        );
      }
    }

    if (product == null) {
      final storeName = Platform.isIOS ? 'App Store' : 'Play Store';
      onPurchaseResult?.call(
        false,
        'This plan is currently unavailable in $storeName. Products: ${candidateIds.join(", ")}',
      );
      debugPrint('Product not found in store: $candidateIds');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseResult?.call(false, 'Failed to initiate purchase: $e');
    }
  }

  Future<void> buyPackage(int packageId, int months) async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available');
      return;
    }

    final productId = getProductIdFromPackageId(packageId, months);

    ProductDetails? product = products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );

    if (product == null) {
      final fetched = await fetchProducts({productId});
      if (fetched.isNotEmpty) {
        product = fetched.first;
      }
    }

    if (product == null) {
      final storeName = Platform.isIOS ? 'App Store' : 'Play Store';
      onPurchaseResult?.call(
        false,
        'This plan is currently unavailable in $storeName. Product: $productId',
      );
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseResult?.call(false, 'Failed to initiate purchase: $e');
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('Purchase pending: ${purchaseDetails.productID}');
          break;

        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchaseDetails.error}');
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          onPurchaseResult?.call(
            false,
            purchaseDetails.error?.message ?? 'Purchase failed',
          );
          break;

        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled: ${purchaseDetails.productID}');
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          onPurchaseResult?.call(false, 'Purchase cancelled');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint(
            'Purchase ${purchaseDetails.status.name}: '
            '${purchaseDetails.productID} id=${purchaseDetails.purchaseID}',
          );

          final activated = await _verifyPurchaseWithBackend(purchaseDetails);

          if (activated) {
            await ApiClient.clearCache();
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchaseDetails);
            }
            onPurchaseResult?.call(true, null);
          } else {
            // Do NOT complete — StoreKit will redeliver until entitlement is granted.
            onPurchaseResult?.call(
              false,
              _lastBackendError ??
                  'Subscription could not be activated. Check your connection and tap Restore Purchases.',
            );
          }
          break;
      }
    }
  }

  Future<bool> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    _lastBackendError = null;

    final token = await ApiClient.getToken();
    if (token == null) {
      _lastBackendError =
          'Please sign in to your RealtorOne account before purchasing.';
      return false;
    }

    final paymentId = _resolvePaymentId(purchase);
    if (paymentId.isEmpty) {
      _lastBackendError = 'Invalid purchase transaction from the App Store.';
      return false;
    }

    final productId = purchase.productID;
    final tierMonthsMap = _parseTierProduct(productId);

    if (tierMonthsMap != null) {
      try {
        final res = await SubscriptionApi.purchaseSubscriptionByTier(
          tierName: tierMonthsMap['tier'] as String,
          months: tierMonthsMap['months'] as int,
          paymentId: paymentId,
          receipt: Platform.isIOS
              ? purchase.verificationData.serverVerificationData
              : null,
          productId: productId,
          platform: Platform.isIOS ? 'ios' : 'android',
        );

        if (res['success'] == true) {
          debugPrint('Subscription activated on server for $productId');
          return true;
        }

        if (res['status'] == 'error') {
          _lastBackendError = res['message']?.toString() ??
              'Could not reach the server. Check your connection.';
          return false;
        }

        _lastBackendError =
            res['message']?.toString() ?? 'Server rejected subscription activation';
        debugPrint('Backend activation failed: $_lastBackendError');
        return false;
      } catch (e) {
        _lastBackendError = 'Network error while activating subscription: $e';
        debugPrint(_lastBackendError);
        return false;
      }
    }

    // Legacy product ID format
    final parts = productId.split('_');
    if (parts.length >= 3) {
      try {
        final packageId = int.parse(parts[1]);
        final monthsStr = parts[2].replaceAll('m', '');
        final months = int.parse(monthsStr);

        final res = await SubscriptionApi.purchaseSubscription(
          packageId: packageId,
          months: months,
          paymentId: paymentId,
          productId: productId,
          platform: Platform.isIOS ? 'ios' : 'android',
        );

        if (res['success'] == true) {
          return true;
        }
        _lastBackendError =
            res['message']?.toString() ?? 'Server rejected subscription activation';
        return false;
      } catch (e) {
        _lastBackendError = 'Failed to verify purchase with backend: $e';
        return false;
      }
    }

    _lastBackendError = 'Unknown product ID: $productId';
    return false;
  }

  String _resolvePaymentId(PurchaseDetails purchase) {
    final purchaseId = purchase.purchaseID?.trim();
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return purchaseId;
    }

    final local = purchase.verificationData.localVerificationData.trim();
    if (local.isNotEmpty) {
      return 'APPLE_LOCAL_${local.hashCode.abs()}';
    }

    return 'APPLE_${purchase.productID}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic>? _parseTierProduct(String productId) {
    final cleanId = productId.replaceFirst('com.realtorone.app.', '');

    for (final entry in _tierProductPrefix.entries) {
      if (cleanId.startsWith(entry.value)) {
        for (final durEntry in _durationSuffix.entries) {
          if (cleanId == '${entry.value}_${durEntry.value}') {
            return {
              'tier': entry.key[0].toUpperCase() + entry.key.substring(1),
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
