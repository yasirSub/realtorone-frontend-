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
    }
  }

  /// Builds the expected Product ID based on package ID and duration.
  /// Example: com.realtorone.tier_1_1m
  String getProductId(int packageId, int months) {
    return 'com.realtorone.tier_${packageId}_${months}m';
  }

  Future<List<ProductDetails>> fetchProducts(Set<String> productIds) async {
    if (!isAvailable) return [];
    final response = await _inAppPurchase.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('Error fetching products: ${response.error}');
    }
    products = response.productDetails;
    return products;
  }

  Future<void> buyPackage(int packageId, int months) async {
    if (!isAvailable) {
      onPurchaseResult?.call(false, 'Store not available');
      return;
    }

    final productId = getProductId(packageId, months);
    
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
      onPurchaseResult?.call(false, 'Product not found ($productId). Ensure it is configured in App Store Connect / Google Play Console.');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      // Consumable vs Non-Consumable (Subscriptions use buyNonConsumable)
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
    // We need to extract the packageId and months from the product ID to send to the backend
    // Assuming format: com.realtorone.tier_{packageId}_{months}m
    final parts = purchase.productID.split('_');
    if (parts.length >= 3) {
      try {
        final packageId = int.parse(parts[1]);
        final monthsStr = parts[2].replaceAll('m', '');
        final months = int.parse(monthsStr);

        final res = await SubscriptionApi.purchaseSubscription(
          packageId: packageId,
          months: months,
          paymentId: purchase.purchaseID ?? 'APPLE_${DateTime.now().millisecondsSinceEpoch}',
          // Apple receipt could be sent here in the future
        );

        if (res['success'] == true) {
          onPurchaseResult?.call(true, null);
        } else {
          onPurchaseResult?.call(false, res['message'] ?? 'Backend validation failed');
        }
      } catch (e) {
        onPurchaseResult?.call(false, 'Failed to parse product ID or sync with backend: $e');
      }
    } else {
      onPurchaseResult?.call(false, 'Unknown product ID format: ${purchase.productID}');
    }
  }

  void dispose() {
    if (!kIsWeb) {
      _subscription.cancel();
    }
  }
}
