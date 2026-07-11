import 'package:flutter/material.dart';

import '../models/external_wallet.dart';
import '../models/fee_estimate.dart';

/// Callback invoked when the user confirms the withdrawal.
typedef OnWithdrawalConfirmed = void Function();

/// Callback invoked when the user cancels the withdrawal.
typedef OnWithdrawalCancelled = void Function();

/// A confirmation screen widget showing the fee breakdown and destination
/// details before the End_User signs the withdrawal transaction.
///
/// Requirement 31.9: The Flutter SDK SHALL present a confirmation screen
/// showing the fee breakdown (network fee, amount to be received at
/// destination) and the destination address label before the End_User
/// signs the transaction.
class WithdrawalConfirmationScreen extends StatelessWidget {
  /// The fee estimate for this withdrawal.
  final FeeEstimate feeEstimate;

  /// The destination external wallet.
  final ExternalWallet destination;

  /// The amount the user wants to withdraw.
  final double withdrawalAmount;

  /// The token symbol being withdrawn.
  final String tokenSymbol;

  /// Callback when the user confirms.
  final OnWithdrawalConfirmed onConfirmed;

  /// Callback when the user cancels.
  final OnWithdrawalCancelled onCancelled;

  const WithdrawalConfirmationScreen({
    super.key,
    required this.feeEstimate,
    required this.destination,
    required this.withdrawalAmount,
    required this.tokenSymbol,
    required this.onConfirmed,
    required this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Withdrawal'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancelled,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Destination section
              _buildSectionHeader(context, 'Destination'),
              const SizedBox(height: 8),
              _buildDestinationCard(context),
              const SizedBox(height: 24),

              // Fee breakdown section
              _buildSectionHeader(context, 'Fee Breakdown'),
              const SizedBox(height: 8),
              _buildFeeBreakdownCard(context),
              const SizedBox(height: 24),

              // Summary section
              _buildSectionHeader(context, 'Summary'),
              const SizedBox(height: 8),
              _buildSummaryCard(context),

              const Spacer(),

              // Estimated time
              Center(
                child: Text(
                  'Estimated confirmation: ${_formatDuration(feeEstimate.estimatedConfirmationSeconds)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              ElevatedButton(
                onPressed: onConfirmed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirm & Sign'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onCancelled,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildDestinationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 20),
                const SizedBox(width: 8),
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _truncateAddress(destination.address),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Network: ${destination.chainType.toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBreakdownCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFeeRow(
              context,
              'Network Fee',
              '${feeEstimate.networkFee} ${feeEstimate.feeToken}',
            ),
            if (feeEstimate.feeToken != tokenSymbol)
              _buildFeeRow(
                context,
                'Fee (in $tokenSymbol)',
                '${feeEstimate.networkFeeInToken} $tokenSymbol',
              ),
            const Divider(),
            _buildFeeRow(
              context,
              'You send',
              '$withdrawalAmount $tokenSymbol',
              isBold: true,
            ),
            _buildFeeRow(
              context,
              'Recipient receives',
              '${feeEstimate.amountAfterFees} $tokenSymbol',
              isBold: true,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are sending $withdrawalAmount $tokenSymbol to '
                '"${destination.label}" on ${destination.chainType.toUpperCase()}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '~$seconds seconds';
    if (seconds < 3600) return '~${seconds ~/ 60} minutes';
    return '~${seconds ~/ 3600} hours';
  }
}
