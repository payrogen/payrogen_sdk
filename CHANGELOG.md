## 0.4.24

### Added
- Updates

## 0.4.23

### Fixed
- Minor bugs

## 0.4.22

### Fixed
- Minor bugs

## 0.4.21

### Changed
- Crypto checkout now uses Solflare (and any Solana Pay compatible smart contract QRCode scanner).

### Fixed
- Minor bugs

## 0.4.20

### Fixed
- Minor wallet bug

## 0.4.19

### Fixed
- Minor bugs

## 0.4.18

### Fixed
- Platform commission bugs

## 0.4.17

### Fixed
- Minor bugs

## 0.4.16

### Fixed
- Minor bugs

## 0.4.15

### Fixed
- Minor bugs

## 0.4.14

### Fixed
- Minor bugs

## 0.4.13

### Fixed
- Minor bugs

## 0.4.12

### Fixed
- Minor bugs

## 0.4.11

### Fixed
- Minor bugs

## 0.4.10

### Fixed
- Minor bugs

## 0.4.9

### Fixed
- Minor bugs

## 0.4.8

### Fixed
- Minor bugs

## 0.4.7

### Fixed
- Card payment form was not showing (only a "Continue to Payment" button appeared).
- Circle 422 "unprocessable entity" errors caused by client-side Dart RSA encryption incompatibility.

## 0.4.6

## Fixed
- Minor bugs

## 0.4.5

## Fixed
- Minor bugs

## 0.4.4

### Added
- **Circle Payments integration** — Headless card-to-USDC payment flow using Circle Payments API with client-side RSA-OAEP encryption (PCI compliant).
- `CircleService` — Fetches Circle encryption key, encrypts card data locally, submits payment, and polls for confirmation.
- `CircleCardForm` widget — Native card entry form with input validation, client-side encryption, and payment processing.
- `CardProvider.circle` enum value for gateway card provider selection.
- `circlePaymentId` field on `PayRogenCheckoutResult`.

### Changed
- Updated `flutter_secure_storage` to ^11.0.0 for latest platform support.
- Updated `flutter_lints` to ^6.0.0 for latest analysis rules.
- Added `pointycastle` and `uuid` dependencies for Circle card encryption.

## 0.4.2

### Fixed
- Fixed "UNKNOWN PLATFORMS" on pub.dev by correcting pubspec platform declaration format.

## 0.4.1

### Fixed
- Removed explicit `platforms` declaration that caused pub.dev to report "UNKNOWN PLATFORMS". Platform support is now auto-detected from dependencies (Android, iOS, Web, macOS, Windows, Linux).

## 0.4.0

### Changed
- **QR code and wallet buttons now route through the smart contract** — uses Solana Pay Transaction Request format pointing to the gateway's `/solana-tx` endpoint which builds the `execute_split_payment` program instruction. All payments enforce on-chain splits and gateway fee deduction.
- Wallet deep links (Solflare) pass the transaction request URL so the wallet builds the correct smart contract call.

## 0.3.9

### Fixed
- **Critical**: Payment no longer marked as successful without on-chain confirmation. SDK now polls the gateway's `/pay/:code/status` endpoint and only shows success when the transaction is verified on-chain.
- Changed header/button gradient to PayRogen blue/purple brand colors.
- Removed raw wallet address display from crypto payment screen.

## 0.3.8

### Fixed
- **Wallet connect no longer shows instant success** — SDK now polls for on-chain confirmation (up to 2 min) after wallet is launched. Success only shown when transaction is verified.
- **Connect Solflare fixed** — uses correct Solflare universal link (`solflare.com/ul/v1/pay`).
- **Removed raw wallet address display** — payments go through the smart contract via Solana Pay transaction request, not direct transfers.
- **QR code now encodes Solana Pay transaction request URL** pointing to the gateway's `/solana-tx` endpoint (ensures splits, fees, and escrow are enforced on-chain).

## 0.3.7

### Changed
- **Crypto payment screen redesigned** to match the web checkout:
  - Added "Connect Solflare" button with deep linking
  - Added Solana Pay compatible QR code
  - Removed manual "I've Sent the Payment" button — payment detection now uses polling after wallet launch
  - Wallet address shown compactly with copy button

### Added
- `qr_flutter` dependency for QR code generation
- `url_launcher` dependency for wallet deep linking
- Auto-payment polling after wallet app is launched

## 0.3.6

### Fixed
- `Wallet.fromJson` no longer crashes with `type 'Null' is not a subtype of type 'String'` when gateway returns null fields. All fields now have safe null fallbacks.

## 0.3.5

### Fixed
- Resolved all deprecated API usages (`withOpacity` → `withValues`, `Color.blue` → modern API).
- Fixed lint info: use null-aware operator.
- Static analysis now reports **zero issues** (targeting 160/160 pub points).

## 0.3.4

### Added
- `exportPrivateKey(userId)` — Allows wallet owners to export their private key for use in external wallets (Solflare, Backpack, etc.).
- Marketplace Integration guide in README.

### Fixed
- **Critical**: All API endpoints now use the correct `/api/v1/` prefix. Previously the SDK was calling `/v1/...` which returned 404 from the gateway.

## 0.3.3

### Changed
- Updated all split examples to reflect 1.5% platform fee (was incorrectly showing 10-15%).

## 0.3.2

### Changed
- Updated README: clarified non-custodial wallet description.

## 0.3.1

### Changed
- Updated README documentation.

## 0.3.0

### Added
- **Drop-in Checkout UI** — `payrogen.checkout()` single method that shows the full payment sheet with zero custom UI code required.
- **Escrow Mode** — Pass `escrow: true` to `checkout()` to create escrow payments with auto-release timeout.
- `releaseEscrow()` — Release funds after delivery confirmation.
- `disputeEscrow()` — Dispute an escrow payment with a reason.
- **Theme-aware UI** — Checkout sheet automatically adapts to your app's light/dark theme.
- **Custom accent color** — Optional `accentColor` parameter for brand customization.
- **PayRogenCheckoutResult** — Rich result object with `success`, `cancelled`, `signature`, `escrowId`, `walletAddress`, `amount`, `currency`, and `metadata`.
- **Split payments** — Pass `splits` map to `checkout()` for automatic on-chain fee splitting.
- **Metadata** — Attach arbitrary metadata (order IDs, user IDs) to transactions.
- **Success animation** — Built-in success screen after payment confirmation.

### Changed
- Bumped minimum version to 0.3.0.
- `CheckoutResult` is now a type alias for `PayRogenCheckoutResult` (backward compatible).
- `PaymentCheckoutSheet` UI completely redesigned with gradient header, card-based method selection, and polished animations.

## 0.2.0

- Initial release with wallet creation, direct payments, escrow, recovery, and basic checkout widget.
- Multi-chain wallet support (Solana, EVM, Bitcoin).
- External wallet management with cooldown periods.
- Withdrawal with fee estimation.
- Network mismatch pre-flight validation.
- Offline retry queue with exponential backoff.
