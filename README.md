# PayRogen SDK for Flutter

Non-custodial, instant-settlement payment gateway SDK for Flutter applications.
Accept crypto and card payments with a single method call.

## Features

- **Drop-in Checkout UI** — `payrogen.checkout()` shows a polished payment sheet (zero custom UI needed)
- **Theme-aware** — Automatically adapts to your app's light/dark theme
- **Pay with Crypto** — Wallet address display with copy button and QR support
- **Pay with Card** — Visa, Mastercard, Apple Pay, Google Pay via Crossmint/Halliday
- **Escrow Payments** — Lock funds until delivery confirmation with auto-release timeout
- **Split Payments** — On-chain atomic fee splitting (e.g., 90% seller, 10% platform)
- **Non-custodial Wallets** — Create wallets via Shamir's Secret Sharing
- **Multi-chain** — Solana, Ethereum, Polygon, Arbitrum, Base, Bitcoin
- **Sandbox + Live** — Solana Devnet for testing, Mainnet for production

## Installation

```yaml
dependencies:
  payrogen_sdk: ^0.3.0
```

## Quick Start — Drop-in Checkout (Recommended)

The fastest way to accept payments. Five lines of code, zero UI work:

```dart
import 'package:payrogen_sdk/payrogen_sdk.dart';

// Initialize once
final payrogen = await PayRogen.init(apiKey: 'ck_live_...');

// When user taps "Checkout":
final result = await payrogen.checkout(
  context: context,
  amount: 20.00,
  currency: 'USDC',
  merchantName: 'InstaFoody',
  description: 'Gluten-free Vegan Pizza Recipe',
  recipientAddress: 'seller_wallet_address',
  splits: {
    'seller_address': 9000,   // 90% to seller
    'platform_address': 1000, // 10% platform fee
  },
);

if (result.success) {
  print('Paid! Signature: ${result.signature}');
} else if (result.cancelled) {
  print('User cancelled');
}
```

## Escrow Payments

For marketplace transactions that need delivery confirmation:

```dart
final result = await payrogen.checkout(
  context: context,
  amount: 50.00,
  currency: 'USDC',
  recipientAddress: 'chef_wallet',
  escrow: true,
  escrowTimeout: Duration(days: 7),
  splits: {'chef': 8500, 'platform': 1500},
);

// Later, when buyer confirms delivery:
await payrogen.releaseEscrow(escrowId: result.escrowId!);

// Or dispute:
await payrogen.disputeEscrow(escrowId: result.escrowId!, reason: 'Not delivered');
```

## Checkout Result

```dart
class PayRogenCheckoutResult {
  final bool success;
  final bool cancelled;
  final String? signature;      // Solana transaction signature
  final String? escrowId;       // Only if escrow: true
  final String? walletAddress;  // Payer's wallet
  final double amount;
  final String currency;
  final Map<String, dynamic>? metadata;
}
```

## Direct API Usage

For advanced use cases where you need full control:

```dart
// Create a wallet
final wallet = await payrogen.createWallet(userId: 'user_123');

// Direct payment
final payment = await payrogen.payDirect(
  amount: 100.0,
  currency: 'USDT',
  from: wallet.publicAddress,
  to: 'recipient_address',
  splits: {'seller': 9000, 'platform': 1000},
);

// Escrow payment
final escrow = await payrogen.payEscrow(
  amount: 200.0,
  currency: 'USDC',
  payer: buyerAddress,
  serviceProvider: sellerAddress,
  platform: platformAddress,
  splits: {'seller': 8500, 'platform': 1500},
);

// Wallet recovery
final recovery = await payrogen.recoverWallet(
  userId: 'user_123',
  phrase: 'recovery phrase here',
);
```

## Customization

```dart
await payrogen.checkout(
  context: context,
  amount: 25.00,
  currency: 'USDC',
  recipientAddress: 'wallet_address',
  accentColor: Colors.purple, // Custom brand color
  metadata: {'order_id': '123', 'item': 'pizza'},
);
```

## Environment

| Environment | Network | Base URL |
|---|---|---|
| `PayRogenEnvironment.sandbox` | Solana Devnet | sandbox-api.payrogen.com |
| `PayRogenEnvironment.live` | Solana Mainnet | api.payrogen.com |

## Error Handling

```dart
try {
  final result = await payrogen.checkout(...);
} on PayRogenValidationException catch (e) {
  print('Validation error: ${e.message}');
} on PayRogenAuthException {
  print('Invalid API key');
} on PayRogenNetworkException {
  print('Gateway unreachable');
} on PayRogenRateLimitException catch (e) {
  print('Rate limited. Retry after: ${e.retryAfter}');
}
```

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ✅ |
| macOS    | ✅ |
| Windows  | ✅ |
| Linux    | ✅ |

## Additional Information

- [Documentation](https://docs.payrogen.com)
- [API Reference](https://api.payrogen.com)
- [Issues](https://github.com/payrogen/payrogen_sdk/issues)
