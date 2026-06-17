import 'dart:ui';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import '../services/iap_service.dart';

/// Display currency for subscription UI (store prices + AED backend fallbacks).
class SubscriptionPricing {
  SubscriptionPricing._();

  /// Fallback when server rate is not loaded yet.
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

  static String deviceCountryCode() {
    return PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
  }

  /// Format a total computed from AED monthly base (fallback when store price missing).
  static String formatAedTotal(double aedAmount, {double? inrRate}) {
    final rate = inrRate ?? aedToInrRate;
    if (useIndianRupee) {
      final inr = aedAmount * rate;
      return _inrFormat.format(inr.round());
    }
    return 'AED ${aedAmount.toStringAsFixed(2)}';
  }

  static String formatAedLabel(double aedAmount) {
    return 'AED ${aedAmount.toStringAsFixed(2)}';
  }

  static String formatInrLabel(double inrAmount) {
    return _inrFormat.format(inrAmount.round());
  }

  /// Same rounding as backend `RazorpayPaymentService::aedToPaise`.
  static double inrChargeFromAed(double amountAed, double rate) {
    final paise = (amountAed * rate * 100).round();
    final clamped = paise < 100 ? 100 : paise;
    return clamped / 100;
  }

  /// Razorpay checkout line: AED list + exact INR charge from server.
  static String formatRazorpayCheckout({
    required double amountAed,
    required double amountInr,
  }) {
    return '${formatAedLabel(amountAed)} (${formatInrLabel(amountInr)} via Razorpay)';
  }

  /// Pick store or fallback price for a tier + duration.
  static String displayPrice({
    required String tierName,
    required int selectedMonths,
    required double aedTotal,
    ProductDetails? storeProduct,
    bool preferAed = false,
    double? inrRate,
  }) {
    if (preferAed) {
      return formatAedLabel(aedTotal);
    }

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
        return formatAedTotal(aedTotal, inrRate: inrRate);
      }
      return storeProduct.price;
    }
    return formatAedTotal(aedTotal, inrRate: inrRate);
  }
}
