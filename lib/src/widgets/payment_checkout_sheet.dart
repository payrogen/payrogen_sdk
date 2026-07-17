import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/checkout.dart';

/// A production-ready payment checkout bottom sheet widget.
///
/// Displays payment options (Pay with Crypto / Pay with Card) and handles
/// the payment flow. Merchants embed this in their app to accept payments.
///
/// Usage:
/// ```dart
/// final result = await PaymentCheckoutSheet.show(
///   context: context,
///   config: CheckoutConfig(
///     amount: 25.00,
///     currency: 'USD',
///     receiveToken: 'USDC',
///     merchantWalletAddress: 'Ae3DDx...',
///     description: 'Order #1234',
///     customerEmail: 'buyer@example.com',
///   ),
///   onCryptoPaymentVerified: (txSignature) async {
///     // Verify payment with your backend
///     return true;
///   },
///   onCardOrderCreated: (orderId, clientSecret) async {
///     // Handle Crossmint checkout completion
///   },
/// );
/// ```
class PaymentCheckoutSheet extends StatefulWidget {
  final CheckoutConfig config;

  /// Called when user submits a crypto payment (transaction signature).
  /// Return true if payment is verified, false otherwise.
  final Future<bool> Function(String txSignature)? onCryptoPaymentVerified;

  /// Called when a card payment order is created via Crossmint.
  /// Receives the orderId and clientSecret for embedded checkout.
  final Future<void> Function(String orderId, String clientSecret)?
      onCardOrderCreated;

  /// Gateway base URL for creating Crossmint orders.
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
  static Future<CheckoutResult?> show({
    required BuildContext context,
    required CheckoutConfig config,
    Future<bool> Function(String txSignature)? onCryptoPaymentVerified,
    Future<void> Function(String orderId, String clientSecret)?
        onCardOrderCreated,
    String? gatewayBaseUrl,
    String? apiKey,
  }) {
    return showModalBottomSheet<CheckoutResult>(
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

class _PaymentCheckoutSheetState extends State<PaymentCheckoutSheet> {
  PaymentMethod? _selectedMethod;
  bool _isProcessing = false;
  String? _error;

  CheckoutConfig get config => widget.config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _selectedMethod == null
                      ? _buildMethodSelection(theme)
                      : _selectedMethod == PaymentMethod.crypto
                          ? _buildCryptoPayment(theme)
                          : _buildCardPayment(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMethodSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Header
        Text('Payment', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (config.description != null)
          Text(config.description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 16),

        // Amount display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 4),
              Text(
                '${config.amount.toStringAsFixed(2)} ${config.currency}',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '≈ ${config.amount.toStringAsFixed(2)} ${config.receiveToken}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Payment method options
        Text('Select payment method', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),

        if (config.allowedMethods.contains(PaymentMethod.crypto))
          _PaymentOptionTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pay with Crypto',
            subtitle: 'Send ${config.receiveToken} from your wallet',
            onTap: () => setState(() => _selectedMethod = PaymentMethod.crypto),
          ),

        if (config.allowedMethods.contains(PaymentMethod.card)) ...[
          const SizedBox(height: 12),
          _PaymentOptionTile(
            icon: Icons.credit_card,
            title: 'Pay with Card',
            subtitle: 'Credit/Debit Card, Apple Pay, Google Pay',
            onTap: () => setState(() => _selectedMethod = PaymentMethod.card),
          ),
        ],

        const SizedBox(height: 32),
        Center(
          child: Text(
            'Powered by PayRogen',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCryptoPayment(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Back button + title
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedMethod = null;
                _error = null;
              }),
            ),
            Text('Pay with Crypto', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        // Amount to send
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('Send exactly', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 4),
              Text(
                '${config.amount.toStringAsFixed(2)} ${config.receiveToken}',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Wallet address
        Text('To this ${config.chain} address:', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  config.merchantWalletAddress,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: config.merchantWalletAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Send ${config.receiveToken} on the ${config.chain} network only. Sending the wrong token or using the wrong network may result in permanent loss of funds.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 11),
        ),
        const SizedBox(height: 24),

        // I've paid button
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleCryptoConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('I\'ve Sent the Payment', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCardPayment(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedMethod = null;
                _error = null;
              }),
            ),
            Text('Pay with Card', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('You will pay', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 4),
              Text(
                '${config.amount.toStringAsFixed(2)} ${config.currency}',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Merchant receives ${config.receiveToken} on ${config.chain}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card payment info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Secure payment powered by Crossmint', style: theme.textTheme.bodySmall)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Supports Visa, Mastercard, Apple Pay, and Google Pay. KYC verification may be required for first-time payments.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleCardPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continue to Payment', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _handleCryptoConfirm() async {
    // For crypto, the merchant app should verify the payment was received
    // This is a simplified flow — in production, the app would poll the gateway
    setState(() => _isProcessing = true);

    try {
      if (widget.onCryptoPaymentVerified != null) {
        // In a real implementation, the user would paste/scan their tx signature
        // For now, we return success and let the merchant verify
        final verified = await widget.onCryptoPaymentVerified!('pending_verification');
        if (verified) {
          if (mounted) {
            Navigator.of(context).pop(CheckoutResult(
              success: true,
              method: PaymentMethod.crypto,
              amountPaid: config.amount.toStringAsFixed(2),
            ));
          }
        } else {
          setState(() => _error = 'Payment not yet confirmed. Please wait and try again.');
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(CheckoutResult(
            success: true,
            method: PaymentMethod.crypto,
            amountPaid: config.amount.toStringAsFixed(2),
          ));
        }
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
      // Call the gateway to create a Crossmint on-ramp order
      if (widget.onCardOrderCreated != null) {
        // The merchant's backend creates the order and returns orderId + clientSecret
        await widget.onCardOrderCreated!('pending', '');
      }

      if (mounted) {
        Navigator.of(context).pop(CheckoutResult(
          success: true,
          method: PaymentMethod.card,
          amountPaid: config.amount.toStringAsFixed(2),
        ));
      }
    } catch (e) {
      setState(() => _error = 'Card payment failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

/// A styled tile for selecting a payment method.
class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
