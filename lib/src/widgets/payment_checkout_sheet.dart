import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checkout.dart';
import 'circle_card_form.dart';

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
  String? _cardPaymentId;
  String? _cryptoSignature;
  // Guards against starting more than one polling loop. Polling begins as soon as the
  // crypto screen is shown so payments are detected whether the customer taps
  // "Connect Solflare" (in-app wallet launch) OR scans the QR with a separate device.
  bool _pollStarted = false;

  CheckoutConfig get config => widget.config;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _accentColor {
    if (config.accentColorValue != null) {
      return Color(config.accentColorValue!);
    }
    // PayRogen brand blue
    return const Color(0xFF4F46E5);
  }

  Color get _surfaceColor =>
      _isDark ? const Color(0xFF1A1B2E) : Colors.white;

  Color get _cardColor =>
      _isDark ? const Color(0xFF252640) : const Color(0xFFF5F5F7);

  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

  Color get _textPrimary =>
      _isDark ? Colors.white : const Color(0xFF1A1B2E);

  Color get _textSecondary =>
      _isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);

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
                color: Colors.black.withValues(alpha: 0.2),
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
                    color: _textSecondary.withValues(alpha: 0.3),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F46E5), // PayRogen indigo
            Color(0xFF7C3AED), // PayRogen violet
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            config.escrow ? 'Escrow Payment' : 'Payment Request',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
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
              color: Colors.white.withValues(alpha: 0.7),
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
            subtitle: 'Connect Solflare to pay',
            onTap: () => _openCryptoPayment(),
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
                color: _accentColor.withValues(alpha: 0.12),
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
    // Solana Pay Transaction Request URL — points to the merchant-ui's /api/pay/[code]/solana-tx
    // endpoint which builds the actual smart contract instruction (with splits + gateway fee).
    // IMPORTANT: This must point to the merchant-ui (merchant.payrogen.com), NOT the gateway API.
    // Format: solana:https://<merchant-ui-host>/api/pay/<code>/solana-tx
    const merchantUiUrl = 'https://merchant.payrogen.com';
    final payCode = config.orderId ?? 'checkout';
    final solanaPayUrl = 'solana:$merchantUiUrl/api/pay/$payCode/solana-tx';

    return Column(
      key: const ValueKey('crypto_payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildBackButton('Pay with Crypto'),
        const SizedBox(height: 20),
        _buildPaymentHeader(),
        const SizedBox(height: 24),

        // Connect wallet buttons
        Text(
          'Connect your wallet to pay ${config.amount.toStringAsFixed(2)} ${config.receiveToken}',
          style: TextStyle(color: _textPrimary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        _buildWalletButton(
          label: 'Connect Solflare',
          onTap: () => _launchWallet(),
        ),

        const SizedBox(height: 24),

        // Divider with "Or scan with mobile wallet"
        Row(
          children: [
            Expanded(child: Divider(color: _borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or scan with your mobile wallet',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: _borderColor)),
          ],
        ),

        const SizedBox(height: 20),

        // QR Code — Solana Pay Transaction Request URL (routes through smart contract)
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: QrImageView(
              data: solanaPayUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: Text(
            'Scan with Solflare or any Solana Pay compatible wallet',
            style: TextStyle(color: _textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ),

        // Polling status
        if (_isProcessing)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Waiting for transaction confirmation...',
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 32),
        _buildSecuredByFooter(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWalletButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7C3AED), // PayRogen violet
              Color(0xFF9333EA), // Purple
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Enter the crypto payment screen and immediately begin polling for on-chain
  /// confirmation. Polling must start here (not only after launching a wallet) so a
  /// payment made by scanning the QR with a SEPARATE device is still detected and the
  /// success screen is shown. _startPaymentPolling is idempotent, so launching Solflare
  /// afterwards does not start a second loop.
  void _openCryptoPayment() {
    setState(() => _step = _CheckoutStep.cryptoPayment);
    _startPaymentPolling();
  }

  Future<void> _launchWallet() async {
    setState(() => _error = null);

    // The Solana Pay Transaction Request URL — must point to merchant-ui
    const merchantUiUrl = 'https://merchant.payrogen.com';
    final payCode = config.orderId ?? 'checkout';
    final txRequestUrl = '$merchantUiUrl/api/pay/$payCode/solana-tx';

    // Solflare registers as a handler for `solana:` URIs on mobile.
    // The Solana Pay Transaction Request format is: solana:<https-url>
    // When launched, the wallet fetches the transaction from the URL and prompts signing.
    // Solflare universal link
    final uri = Uri.parse('https://solflare.com/ul/v1/pay?link=${Uri.encodeComponent(txRequestUrl)}');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _error = 'Solflare app not found. Please install it first.');
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open Solflare. Is it installed?');
      }
      return;
    }

    // Start polling for payment confirmation AFTER wallet is launched
    _startPaymentPolling();
  }

  void _startPaymentPolling() {
    // Idempotent: only ever run one polling loop, no matter how many entry points
    // (crypto screen shown, wallet launched, retry) call this.
    if (_pollStarted) return;
    _pollStarted = true;
    if (mounted) {
      setState(() => _isProcessing = true);
    } else {
      _isProcessing = true;
    }
    _pollForPayment();
  }

  Future<void> _pollForPayment() async {
    // Poll every 3 seconds for up to 2 minutes
    const maxAttempts = 40;
    const pollInterval = Duration(seconds: 3);

    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted || _step == _CheckoutStep.success) return;

      await Future.delayed(pollInterval);

      if (!mounted) return;

      try {
        if (widget.onCryptoPaymentVerified != null) {
          final verified = await widget.onCryptoPaymentVerified!('poll_$i');
          if (verified && mounted) {
            // Fetch the transaction signature from the gateway
            try {
              final payCode = config.orderId ?? 'checkout';
              final gatewayUrl = widget.gatewayBaseUrl ?? 'https://sandbox-api.payrogen.com';
              final statusUri = Uri.parse('$gatewayUrl/api/v1/pay/$payCode/status');
              final resp = await http.get(statusUri);
              if (resp.statusCode == 200) {
                final data = jsonDecode(resp.body) as Map<String, dynamic>;
                _cryptoSignature = data['transaction_signature'] as String?;
              }
            } catch (_) {
              // Ignore — signature fetch is best-effort
            }
            setState(() {
              _isProcessing = false;
              _step = _CheckoutStep.success;
            });
            return;
          }
        }
        // If no callback provided, we can't verify — keep polling
      } catch (_) {
        // Continue polling on errors
      }
    }

    // Timed out — payment was NOT confirmed within the window. Allow the customer to
    // resume polling (e.g. a QR payment that is still settling) by resetting the guard
    // so a subsequent action can restart the loop.
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _pollStarted = false;
        _error = 'Still waiting for your payment to confirm. If you have paid, '
            'tap "Connect Solflare" or wait a moment and it will update automatically.';
      });
    } else {
      _pollStarted = false;
    }
  }

  // ─── Card Payment ─────────────────────────────────────────────────────────

  Widget _buildCardPayment() {
    final gatewayBaseUrl = widget.gatewayBaseUrl ?? 'https://pay.payrogen.com';
    final payCode = config.orderId ?? 'checkout';

    return Column(
      key: const ValueKey('card_payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildBackButton('Pay with Card'),
        const SizedBox(height: 20),
        _buildPaymentHeader(),
        const SizedBox(height: 24),

        // Inline Circle card form — collects card details and processes payment
        CircleCardForm(
          gatewayBaseUrl: gatewayBaseUrl,
          paymentCode: payCode,
          amount: config.amount.toStringAsFixed(2),
          email: config.customerEmail ?? '',
          accentColor: _accentColor,
          onPaymentComplete: (result) {
            _cardPaymentId = result.paymentId;
            setState(() => _step = _CheckoutStep.success);
          },
          onPaymentError: (error) {
            setState(() => _error = error);
          },
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
            color: Colors.green.withValues(alpha: 0.12),
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
              signature: _cardPaymentId ?? _cryptoSignature,
              circlePaymentId: _cardPaymentId,
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
          disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
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
}

enum _CheckoutStep {
  methodSelection,
  cryptoPayment,
  cardPayment,
  success,
}
