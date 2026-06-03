import 'package:razorpay_flutter/razorpay_flutter.dart';

/// A service wrapper around the [Razorpay] SDK.
///
/// Usage:
/// ```dart
/// final _service = RazorpayService(
///   onSuccess: _handlePaymentSuccess,
///   onError: _handlePaymentError,
///   onExternalWallet: _handleExternalWallet,
/// );
///
/// // Open checkout
/// await _service.openCheckout(options: {...});
///
/// // Always dispose when the widget is disposed
/// _service.dispose();
/// ```
class RazorpayService {
  /// Called when the payment is completed successfully.
  final void Function(PaymentSuccessResponse) onSuccess;

  /// Called when the payment fails or is cancelled by the user.
  final void Function(PaymentFailureResponse) onError;

  /// Called when the user selects an external wallet (e.g. PhonePe, Paytm).
  final void Function(ExternalWalletResponse) onExternalWallet;

  late final Razorpay _razorpay;

  RazorpayService({
    required this.onSuccess,
    required this.onError,
    required this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  /// Opens the Razorpay checkout sheet with the given [options].
  ///
  /// Required keys in [options]:
  /// - `key`    : your Razorpay API key (test or live)
  /// - `amount` : amount in **paise** (i.e. ₹1 = 100)
  /// - `name`   : merchant / app name shown on the checkout sheet
  ///
  /// Optional but recommended keys:
  /// - `description` : brief description of the purchase
  /// - `prefill`     : map with `contact` and/or `email` to pre-fill fields
  /// - `theme`       : map with `color` (hex string) for checkout branding
  ///
  /// Throws a [RazorpayException] if the checkout cannot be opened (e.g. the
  /// SDK is not properly initialised or the options map is malformed).
  Future<void> openCheckout({required Map<String, dynamic> options}) async {
    _razorpay.open(options);
  }

  /// Releases all event listeners and internal SDK resources.
  ///
  /// Must be called from the owning widget's [dispose] lifecycle method to
  /// prevent memory leaks.
  void dispose() {
    _razorpay.clear();
  }
}
