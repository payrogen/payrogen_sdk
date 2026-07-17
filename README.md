# PayRogen SDK for Flutter

Non-custody, Instant settlement payment gateway SDK for Flutter/Dart applications.

## Features

- **Payment Checkout UI** — Drop-in payment sheet with Pay with Crypto + Pay with Card
- **Card Payments** — Credit/Debit Card, Apple Pay, Google Pay via Crossmint on-ramp
- **Crypto Payments** — Shows merchant wallet address + QR for direct transfer
- Non-custodial wallet creation via Shamir's Secret Sharing
- Direct split payments (atomic, on-chain)
- Escrow payments with timeout protection
- Wallet recovery with duress phrase support
- Sandbox and live environment support
- Automatic retry with exponential backoff
- Custom base URL for local development

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  payrogen_sdk: ^0.2.0
```

## Quick Start

```dart
import 'package:payrogen_sdk/payrogen_sdk.dart';

// 1. Initialize the SDK
final payrogen = await PayRogen.init(
  apiKey: 'ck_live_your_api_key_here',
  environment: PayRogenEnvironment.live,
);

// 2. Create a wallet for your user
final wallet = await payrogen.createWallet(userId: 'user_123');
print('Wallet address: ${wallet.publicAddress}');

// 3. Make a direct payment with splits
final payment = await payrogen.payDirect(
  amount: 100.0,
  currency: 'USDT',
  from: wallet.publicAddress,
  to: 'seller_address',
  splits: {
    'seller_address': 9000,    // 90% to seller
    'platform_address': 1000,  // 10% platform fee
  },
);
print('Transaction: ${payment.signature}');
```

## API Reference

### `PayRogen.init(apiKey, environment)`

Initializes the SDK and authenticates with the PayRogen Gateway.

### `createWallet(userId)`

Creates a non-custodial wallet for the specified user.

### `payDirect(amount, currency, from, to, splits, ...)`

Executes an atomic direct split payment on-chain.

### `payEscrow(amount, currency, payer, serviceProvider, platform, splits, ...)`

Creates an escrow payment that locks funds until delivery confirmation.

### `recoverWallet(userId, phrase)`

Recovers wallet access. If a duress phrase is used, triggers a silent wallet freeze.

## Environment

- `PayRogenEnvironment.sandbox` — Uses Solana Devnet and test tokens
- `PayRogenEnvironment.live` — Uses Solana Mainnet

## Error Handling

```dart
try {
  final payment = await payrogen.payDirect(...);
} on PayRogenValidationException catch (e) {
  print('Validation error: ${e.message}');
} on PayRogenAuthException catch (e) {
  print('Auth error: ${e.message}');
} on PayRogenNetworkException catch (e) {
  print('Network error: ${e.message}');
} on PayRogenRateLimitException catch (e) {
  print('Rate limited. Retry after: ${e.retryAfter}');
}
```
