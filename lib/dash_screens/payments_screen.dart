import 'package:flutter/material.dart';
import 'package:pay/pay.dart';
import 'payment_config.dart'; // Import your payment configuration file

class PaymentsScreen extends StatefulWidget {
  final String schoolCode;

  const PaymentsScreen({super.key, required this.schoolCode, required String userId});

  @override
  PaymentsScreenState createState() => PaymentsScreenState();
}

class PaymentsScreenState extends State<PaymentsScreen> {
  final List<PaymentItem> paymentItems = [
    const PaymentItem(
      label: 'Total',
      amount: '99.99',
      status: PaymentItemStatus.final_price,
    )
  ];

  void onApplePayResult(paymentResult) {
    // Send the resulting Apple Pay token to your server / PSP
    debugPrint('Apple Pay Result: ${paymentResult.toString()}');
    // TODO: Implement server communication
  }

  void onGooglePayResult(paymentResult) {
    // Send the resulting Google Pay token to your server / PSP
    debugPrint('Google Pay Result: ${paymentResult.toString()}');
    // TODO: Implement server communication
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments for ${widget.schoolCode}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ApplePayButton(
              paymentConfiguration: PaymentConfiguration.fromJsonString(defaultApplePay),
              paymentItems: paymentItems,
              style: ApplePayButtonStyle.black,
              type: ApplePayButtonType.buy,
              margin: const EdgeInsets.only(top: 15.0),
              onPaymentResult: onApplePayResult,
              loadingIndicator: const Center(
                child: CircularProgressIndicator(),
              ),
              onError: (error) {
                debugPrint('Apple Pay Error: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Apple Pay is not available: $error')),
                );
              },
            ),
            GooglePayButton(
              paymentConfiguration: PaymentConfiguration.fromJsonString(defaultGooglePay),
              paymentItems: paymentItems,
              type: GooglePayButtonType.buy,
              margin: const EdgeInsets.only(top: 15.0),
              onPaymentResult: onGooglePayResult,
              loadingIndicator: const Center(
                child: CircularProgressIndicator(),
              ),
              onError: (error) {
                debugPrint('Google Pay Error: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Google Pay is not available: $error')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}