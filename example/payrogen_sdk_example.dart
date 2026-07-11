// ignore_for_file: avoid_print, unused_local_variable

import 'package:payrogen_sdk/payrogen_sdk.dart';

/// Example demonstrating PayRogen SDK usage.
///
/// This shows the basic workflow: initialize → create wallet → make payment.
Future<void> main() async {
  // 1. Initialize the SDK with your API key
  final payrogen = await PayRogen.init(
    apiKey: 'ck_sandbox_your_api_key_here',
    environment: PayRogenEnvironment.sandbox,
  );

  // 2. Create a non-custodial wallet for your user
  final wallet = await payrogen.createWallet(userId: 'user_123');
  print('Wallet created: ${wallet.publicAddress}');

  // 3. Make a direct split payment
  final payment = await payrogen.payDirect(
    amount: 50.0,
    currency: 'USDT',
    from: wallet.publicAddress,
    to: 'seller_wallet_address',
    splits: {
      'seller_wallet_address': 9000, // 90% to seller
      'platform_wallet_address': 750, // 7.5% platform fee
      'payrogen_treasury': 250, // 2.5% gateway fee
    },
  );
  print('Payment signature: ${payment.signature}');

  // 4. Create an escrow payment (funds locked until delivery)
  final escrow = await payrogen.payEscrow(
    amount: 100.0,
    currency: 'USDC',
    payer: wallet.publicAddress,
    serviceProvider: 'seller_wallet_address',
    platform: 'platform_wallet_address',
    splits: {
      'seller_wallet_address': 9000,
      'platform_wallet_address': 750,
      'payrogen_treasury': 250,
    },
  );
  print('Escrow created: ${escrow.escrowId}');

  // 5. Recover a wallet (e.g., user logged in on new device)
  final recovered = await payrogen.recoverWallet(
    userId: 'user_123',
    phrase: 'recovery phrase here',
  );
  print('Wallet recovered: ${recovered.publicAddress}');
}
