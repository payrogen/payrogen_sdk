// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter/material.dart';
import 'package:payrogen_sdk/payrogen_sdk.dart';

/// Example: PayRogen drop-in checkout integration.
///
/// The entire payment integration is just 5 lines of code.
void main() {
  runApp(const PayRogenExampleApp());
}

class PayRogenExampleApp extends StatelessWidget {
  const PayRogenExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayRogen Demo',
      // The SDK automatically adapts to your app's theme (light or dark)
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MarketplaceCheckout(),
    );
  }
}

/// Simulates a marketplace checkout (like InstaFoody).
class MarketplaceCheckout extends StatefulWidget {
  const MarketplaceCheckout({super.key});

  @override
  State<MarketplaceCheckout> createState() => _MarketplaceCheckoutState();
}

class _MarketplaceCheckoutState extends State<MarketplaceCheckout> {
  PayRogen? _payrogen;

  @override
  void initState() {
    super.initState();
    _initPayRogen();
  }

  Future<void> _initPayRogen() async {
    _payrogen = await PayRogen.init(apiKey: 'ck_sandbox_your_key_here');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InstaFoody')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Example 1: Simple payment
            ElevatedButton(
              onPressed: () => _simpleCheckout(context),
              child: const Text('Buy Recipe - \$20.00'),
            ),
            const SizedBox(height: 16),

            // Example 2: Escrow payment
            ElevatedButton(
              onPressed: () => _escrowCheckout(context),
              child: const Text('Book Private Chef - \$50.00 (Escrow)'),
            ),
          ],
        ),
      ),
    );
  }

  /// Simple direct payment with split.
  Future<void> _simpleCheckout(BuildContext context) async {
    final payrogen = _payrogen;
    if (payrogen == null) return;

    final result = await payrogen.checkout(
      context: context,
      amount: 20.00,
      currency: 'USDC',
      merchantName: 'InstaFoody',
      description: 'Gluten-free Vegan Pizza Recipe',
      recipientAddress: 'SELLER_WALLET_ADDRESS_HERE',
      splits: {
        'SELLER_WALLET': 9000, // 90% to seller
        'PLATFORM_WALLET': 1000, // 10% platform fee
      },
      metadata: {
        'order_id': 'order_123',
        'buyer_id': 'user_456',
      },
    );

    if (result.success) {
      print('Payment successful! Signature: ${result.signature}');
    } else if (result.cancelled) {
      print('User cancelled checkout');
    }
  }

  /// Escrow payment with delivery confirmation.
  Future<void> _escrowCheckout(BuildContext context) async {
    final payrogen = _payrogen;
    if (payrogen == null) return;

    final result = await payrogen.checkout(
      context: context,
      amount: 50.00,
      currency: 'USDC',
      merchantName: 'InstaFoody',
      description: 'Private Chef Booking - June 20',
      recipientAddress: 'CHEF_WALLET_ADDRESS_HERE',
      splits: {
        'CHEF_WALLET': 8500, // 85% to chef
        'PLATFORM_WALLET': 1500, // 15% platform fee
      },
      escrow: true,
      escrowTimeout: const Duration(days: 7),
      metadata: {
        'booking_id': 'booking_789',
        'service': 'private_chef',
      },
    );

    if (result.success) {
      print('Escrow created! ID: ${result.escrowId}');

      // Later, when buyer confirms delivery:
      // await payrogen.releaseEscrow(escrowId: result.escrowId!);

      // Or if there's a dispute:
      // await payrogen.disputeEscrow(
      //   escrowId: result.escrowId!,
      //   reason: 'Service not provided',
      // );
    }
  }

  @override
  void dispose() {
    _payrogen?.dispose();
    super.dispose();
  }
}
