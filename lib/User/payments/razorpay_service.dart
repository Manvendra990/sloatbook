import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef OnPaymentSuccess = void Function(PaymentSuccessResponse response);
typedef OnPaymentError = void Function(PaymentFailureResponse response);
typedef OnExternalWallet = void Function(ExternalWalletResponse response);

class RazorpayService {
  final Razorpay _razorpay = Razorpay();
  final OnPaymentSuccess? onSuccess;
  final OnPaymentError? onError;
  final OnExternalWallet? onExternalWallet;

  RazorpayService({this.onSuccess, this.onError, this.onExternalWallet}) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (resp) {
      if (onSuccess != null) onSuccess!(resp as PaymentSuccessResponse);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (resp) {
      if (onError != null) onError!(resp as PaymentFailureResponse);
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (resp) {
      if (onExternalWallet != null)
        onExternalWallet!(resp as ExternalWalletResponse);
    });
  }

  Future<void> openCheckout({required Map<String, dynamic> options}) async {
    _razorpay.open(options);
  }

  void dispose() => _razorpay.clear();
}
