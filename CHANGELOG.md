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
