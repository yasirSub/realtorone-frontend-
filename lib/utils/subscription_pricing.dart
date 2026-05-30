import 'dart:ui';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import '../services/iap_service.dart';

/// Display currency for subscription UI (store prices + AED backend fallbacks).
class SubscriptionPricing {
  SubscriptionPricing._();

  /// Backend `price_monthly` values are stored in AED.
  static const double aedToInrRate = 22.75;

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// India if device region is IN, or Play/App Store already returned INR products.
  static bool get useIndianRupee {
    final country =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    if (country == 'IN') return true;
    return IapService().products.any(
      (p) => p.currencyCode.toUpperCase() == 'INR',
    );
  }

  /// Format a total computed from AED monthly base (fallback when store price missing).
  static String formatAedTotal(double aedAmount) {
    if (useIndianRupee) {
      final inr = aedAmount * aedToInrRate;
      return _inrFormat.format(inr.round());
    }
    return 'AED ${aedAmount.toStringAsFixed(2)}';
  }

  /// Pick store or fallback price for a tier + duration.
  static String displayPrice({
    required String tierName,
    required int selectedMonths,
    required double aedTotal,
    ProductDetails? storeProduct,
  }) {
    if (storeProduct != null) {
      final code = storeProduct.currencyCode.toUpperCase();
      if (useIndianRupee && code == 'INR') {
        return storeProduct.price;
      }
      if (!useIndianRupee && (code == 'AED' || code == 'USD')) {
        return storeProduct.price;
      }
      // Region/currency mismatch (e.g. India device but AED-only SKU) → consistent fallback.
      if (useIndianRupee) {
        return formatAedTotal(aedTotal);
      }
      return storeProduct.price;
    }
    return formatAedTotal(aedTotal);
  }
}
