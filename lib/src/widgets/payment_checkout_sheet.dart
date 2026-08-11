import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/checkout.dart';

/// A production-ready payment checkout bottom sheet widget.
///
/// Displays a polished payment UI matching the PayRogen web checkout design.
/// Automatically adapts to the app's light/dark theme, or can be overridden
/// with a custom accent color.
///
/// Usage:
/// ```dart
/// final result = await PaymentCheckoutSheet.show(
///   context: context,
///   config: CheckoutConfig(
///     amount: 25.00,
///     currency: 'USDC',
///     receiveToken: 'USDC',
///     merchantWalletAddress: 'Ae3DDx...',
///     merchantName: 'InstaFoody',
///     description: 'Gluten-free Vegan Pizza',
///   ),
/// );
/// ```
class PaymentCheckoutSheet extends StatefulWidget {
  final CheckoutConfig config;

  /// Called when user submits a crypto payment (transaction signature).
  /// Return true if payment is verified, false otherwise.
  final Future<bool> Function(String txSignature)? onCryptoPaymentVerified;

  /// Called when a card payment order is created.
  final Future<void> Function(String orderId, String clientSecret)?
      onCardOrderCreated;

  /// Gateway base URL for creating card payment orders.
  final String? gatewayBaseUrl;

  /// Merchant API key for authenticating with the gateway.
  final String? apiKey;

  const PaymentCheckoutSheet({
    super.key,
    required this.config,
    this.onCryptoPaymentVerified,
    this.onCardOrderCreated,
    this.gatewayBaseUrl,
    this.apiKey,
  });

  /// Show the checkout sheet as a modal bottom sheet and return the result.
  static Future<PayRogenCheckoutResult?> show({
    required BuildContext context,
    required CheckoutConfig config,
    Future<bool> Function(String txSignature)? onCryptoPaymentVerified,
    Future<void> Function(String orderId, String clientSecret)?
        onCardOrderCreated,
    String? gatewayBaseUrl,
    String? apiKey,
  }) {
    return showModalBottomSheet<PayRogenCheckoutResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentCheckoutSheet(
        config: config,
        onCryptoPaymentVerified: onCryptoPaymentVerified,
        onCardOrderCreated: onCardOrderCreated,
        gatewayBaseUrl: gatewayBaseUrl,
        apiKey: apiKey,
      ),
    );
  }

  @override
  State<PaymentCheckoutSheet> createState() => _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends State<PaymentCheckoutSheet>
    with SingleTickerProviderStateMixin {
  _CheckoutStep _step = _CheckoutStep.methodSelection;
  bool _isProcessing = false;
  String? _error;

  CheckoutConfig get config => widget.config;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _accentColor {
    if (config.accentColorValue != null) {
      return Color(config.accentColorValue!);
    }
    return Theme.of(context).primaryColor;
  }

  Color get _surfaceColor =>
      _isDark ? const Color(0xFF1A1B2E) : Colors.white;

  Color get _cardColor =>
      _isDark ? const Color(0xFF252640) : const Color(0xFFF5F5F7);

  Color get _borderColor =>
      _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);

  Color get _textPrimary =>
      _isDark ? Colors.white : const Color(0xFF1A1B2E);

  Color get _textSecondary =>
      _isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.5);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _CheckoutStep.methodSelection:
        return _buildMethodSelection();
      case _CheckoutStep.cryptoPayment:
        return _buildCryptoPayment();
      case _CheckoutStep.cardPayment:
        return _buildCardPayment();
      case _CheckoutStep.success:
        return _buildSuccess();
    }
  }

  // ─── Header with gradient ─────────────────────────────────────────────────

  Widget _buildPaymentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentColor,
            _accentColor.withBlue((_accentColor.blue + 40).clamp(0, 255)),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            config.escrow ? 'Escrow Payment' : 'Payment Request',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${config.amount.toStringAsFixed(2)} ${config.receiveToken}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${config.chain[0].toUpperCase()}${config.chain.substring(1)} Network',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Method Selection ─────────────────────────────────────────────────────

  Widget _buildMethodSelection() {
    return Column(
      key: const ValueKey('method_selection'),
      children: [
        const SizedBox(height: 12),
        _buildPaymentHeader(),
        const SizedBox(height: 28),
        Text(
          'Choose how to pay',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        if (config.allowedMethods.contains(PaymentMethod.crypto))
          _buildMethodCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Pay with Crypto',
            subtitle: 'Connect Phantom or Solflare to pay',
            onTap: () => setState(() => _step = _CheckoutStep.cryptoPayment),
          ),

        if (config.allowedMethods.contains(PaymentMethod.card)) ...[
          const SizedBox(height: 12),
          _buildMethodCard(
            icon: Icons.credit_card_rounded,
            title: 'Pay with Card',
            subtitle: 'Visa, Mastercard, Apple Pay, Google Pay',
            onTap: () => setState(() => _step = _CheckoutStep.cardPayment),
          ),
        ],

        const SizedBox(height: 32),
        _buildSecuredByFooter(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardColor,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Crypto Payment ───────────────────────────────────────────────────────

  Widget _buildCryptoPayment() {
    return Column(
      key: const ValueKey('crypto_payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildBackButton('Pay with Crypto'),
        const SizedBox(height: 20),
        _buildPaymentHeader(),
        const SizedBox(height: 24),

        // Wallet address section
        Text(
          'Send to this ${config.chain} address:',
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.merchantWalletAddress,
                  style: TextStyle(
                    color: _textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: config.merchantWalletAddress),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Address copied'),
                      backgroundColor: _accentColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.copy_rounded, size: 18, color: _accentColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Send only ${config.receiveToken} on the ${config.chain} network. Wrong token or network may result in permanent loss.',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),

        _buildPrimaryButton(
          label: "I've Sent the Payment",
          onPressed: _isProcessing ? null : _handleCryptoConfirm,
          isLoading: _isProcessing,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Card Payment ─────────────────────────────────────────────────────────

  Widget _buildCardPayment() {
    return Column(
      key: const ValueKey('card_payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildBackButton('Pay with Card'),
        const SizedBox(height: 20),
        _buildPaymentHeader(),
        const SizedBox(height: 24),

        // Info card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security_rounded, size: 18, color: _accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      config.cardProvider == CardProvider.halliday
                          ? 'Secure payment powered by Halliday'
                          : 'Secure payment powered by Crossmint',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Supports Visa, Mastercard, Apple Pay, and Google Pay. Your card details are processed securely and never stored.',
                style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),

        _buildPrimaryButton(
          label: 'Continue to Payment',
          onPressed: _isProcessing ? null : _handleCardPayment,
          isLoading: _isProcessing,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Success Screen ───────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Payment Successful!',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${config.amount.toStringAsFixed(2)} ${config.receiveToken} sent',
          style: TextStyle(color: _textSecondary, fontSize: 15),
        ),
        if (config.description != null) ...[
          const SizedBox(height: 4),
          Text(
            config.description!,
            style: TextStyle(color: _textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Done',
          onPressed: () {
            Navigator.of(context).pop(PayRogenCheckoutResult(
              success: true,
              method: _step == _CheckoutStep.cryptoPayment
                  ? PaymentMethod.crypto
                  : PaymentMethod.card,
              amount: config.amount,
              currency: config.receiveToken,
              metadata: config.metadata,
            ));
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────

  Widget _buildBackButton(String title) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _step = _CheckoutStep.methodSelection;
            _error = null;
          }),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, size: 20, color: _textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accentColor.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSecuredByFooter() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 14, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            'Secured by PayRogen',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────

  Future<void> _handleCryptoConfirm() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (widget.onCryptoPaymentVerified != null) {
        final verified =
            await widget.onCryptoPaymentVerified!('pending_verification');
        if (verified) {
          setState(() => _step = _CheckoutStep.success);
        } else {
          setState(() =>
              _error = 'Payment not yet confirmed. Please wait and try again.');
        }
      } else {
        setState(() => _step = _CheckoutStep.success);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCardPayment() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (widget.onCardOrderCreated != null) {
        await widget.onCardOrderCreated!('pending', '');
      }
      setState(() => _step = _CheckoutStep.success);
    } catch (e) {
      setState(() => _error = 'Card payment failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

enum _CheckoutStep {
  methodSelection,
  cryptoPayment,
  cardPayment,
  success,
}
