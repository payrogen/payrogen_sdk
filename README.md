# PayRogen SDK for Flutter

Non-custodial, instant-settlement payment gateway SDK for Flutter applications.
Accept stablecoin USDC crypto and card (Visa, MasterCard) payments  with a single method call.

## Features

- **Drop-in Checkout UI** — `payrogen.checkout()` shows a polished payment sheet (zero custom UI needed)
- **Theme-aware** — Automatically adapts to your app's light/dark theme
- **Pay with Crypto** — Easy Crypto Payment with your Wallet and QR Code Support using Solflare or any Solana Compatible Wallet
- **Pay with Card** — Visa, Mastercard, Apple Pay, Google Pay
- **Escrow Payments** — Lock funds until delivery confirmation with auto-release timeout
- **Split Payments** — On-chain atomic fee splitting (e.g., 93.5% seller, 5% platform, 1.5% gateway)
- **Non-custodial Wallets** — Users own their private keys with full export capability
- **Multi-chain** — Solana, Ethereum, Polygon, Arbitrum, Base, Bitcoin
- **Sandbox + Live** — Solana Devnet for testing, Mainnet for production

## Installation

```yaml
dependencies:
  payrogen_sdk: ^0.4.24
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
    'seller_address': 9850,   // 98.5% to seller
    'platform_address': 150,  // 1.5% platform fee
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
  splits: {'chef': 9850, 'platform': 150},
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
  splits: {'seller': 9850, 'platform': 150},
);

// Escrow payment
final escrow = await payrogen.payEscrow(
  amount: 200.0,
  currency: 'USDC',
  payer: buyerAddress,
  serviceProvider: sellerAddress,
  platform: platformAddress,
  splits: {'seller': 9850, 'platform': 150},
);

// Wallet recovery
final recovery = await payrogen.recoverWallet(
  userId: 'user_123',
  phrase: 'recovery phrase here',
);

// Export private key (user can import into Solflare or any Solana wallet)
final privateKey = await payrogen.exportPrivateKey(userId: 'user_123');
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

## Marketplace Integration

For marketplaces with multiple sellers (e.g., recipe stores, freelance platforms, food delivery):

### 1. Seller Onboarding — Create a Wallet

When a seller signs up or first lists a product, create their payment wallet:

```dart
// Called once when seller joins the platform
final sellerWallet = await payrogen.createWallet(userId: 'seller_456');

// Store this address in your backend database
final sellerAddress = sellerWallet.publicAddress;
// e.g., save to: sellers table → wallet_address column
```

The wallet is non-custodial — the seller owns it. Call `createWallet()` **once per seller** and cache the address.

### 2. Buyer Checkout — Route Funds to Seller

When a buyer purchases from a specific seller, pass that seller's wallet as the recipient:

```dart
// Fetch sellerWalletAddress from your database
final sellerWalletAddress = await yourBackend.getSellerWallet(sellerId);

final result = await payrogen.checkout(
  context: context,
  amount: 20.00,
  currency: 'USDC',
  merchantName: 'YourMarketplace',
  description: 'Gluten-free Vegan Pizza Recipe',
  recipientAddress: sellerWalletAddress, // Funds go HERE
  splits: {
    sellerWalletAddress: 9850,       // 98.5% to seller
    yourPlatformWallet: 150,         // 1.5% platform commission
  },
  metadata: {'order_id': 'order_123', 'seller_id': 'seller_456'},
);
```

**How the money flows:**
1. Buyer pays 20 USDC
2. PayRogen gateway fee (1.5%) is deducted: 0.30 USDC
3. Remaining 19.70 USDC splits on-chain: 98.5% to seller, 1.5% to your platform

### 3. Seller Exports Private Key

Sellers can export their wallet's private key to use in Solflare or any Solana wallet:

```dart
// Seller taps "Export Wallet" in your app
final privateKey = await payrogen.exportPrivateKey(userId: 'seller_456');

// Show the key to the seller with a security warning
// They can now import it into Solflare and manage funds independently
```

### 4. Complete Flow Summary

```
Seller signs up → createWallet() → store address in your DB
                                  ↓
Buyer checks out → checkout(recipientAddress: sellerAddress, splits: {...})
                                  ↓
Smart contract executes on-chain → gateway fee deducted → split applied
                                  ↓
Seller receives funds directly in their wallet
                                  ↓
Seller can export private key → import into Solflare → withdraw anytime
```

## Additional Information

- [Issues](https://github.com/payrogen/payrogen_sdk/issues)
