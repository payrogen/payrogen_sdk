// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter/material.dart';
import 'package:payrogen_sdk/payrogen_sdk.dart';

/// Example: PayRogen Payment Checkout integration in a Flutter app.
///
/// Shows how to accept payments using the PayRogen SDK with both
/// crypto and card payment options.
void main() {
  runApp(const PayRogenExampleApp());
}

/// Example app demonstrating PayRogen checkout.
class PayRogenExampleApp extends StatelessWidget {
  const PayRogenExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayRogen Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CheckoutDemo(),
    );
  }
}

/// Demo screen with a checkout button.
class CheckoutDemo extends StatelessWidget {
  const CheckoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PayRogen Checkout Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showCheckout(context),
          child: const Text('Pay \$25.00'),
        ),
      ),
    );
  }

  /// Launch the PayRogen payment checkout sheet.
  Future<void> _showCheckout(BuildContext context) async {
    final result = await PaymentCheckoutSheet.show(
      context: context,
      config: const CheckoutConfig(
        amount: 25.00,
        currency: 'USD',
        receiveToken: 'USDC',
        merchantWalletAddress: 'Ae3DDxCkmPzf4AQA4nKaK64dQ2rowaUKzrsspb7NXRNR',
        chain: 'solana',
        description: 'Order #1234 - Coffee & Sandwich',
        customerEmail: 'buyer@example.com',
      ),
      onCryptoPaymentVerified: (txSignature) async {
        // Verify payment with your backend
        print('Verifying crypto payment: $txSignature');
        return true;
      },
      onCardOrderCreated: (orderId, clientSecret) async {
        // Handle Crossmint card payment flow
        print('Card order created: $orderId');
      },
    );

    if (result != null && result.success) {
      print('Payment successful via ${result.method.name}');
    }
  }
}
