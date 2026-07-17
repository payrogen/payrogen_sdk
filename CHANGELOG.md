## 0.2.0

- Added `PaymentCheckoutSheet` widget for drop-in payment UI
- Added `CheckoutConfig` and `CheckoutResult` models
- Added Pay with Crypto (wallet address display) and Pay with Card (Crossmint on-ramp)
- Added `baseUrl` parameter to `PayRogen.init()` for local development
- Updated `flutter_secure_storage` to v10 (removed deprecated `encryptedSharedPreferences`)
- Replaced deprecated `withOpacity` calls with `withValues(alpha:)`
- Bumped minimum SDK to Dart 3.5.0

## 0.1.0

- Initial release
- `PayRogen` class with `init`, `createWallet`, `payDirect`, `payEscrow`, `recoverWallet`
- Multi-chain wallet creation (`createMultiChainWallet`)
- External wallet address book with cooldown
- Withdrawal with fee estimation
- Network mismatch pre-flight validation
- Sandbox and live environment support
- Automatic retry with exponential backoff (3 attempts)
- Typed exception hierarchy
- Secure Share_A storage (iOS Keychain / Android Keystore)
