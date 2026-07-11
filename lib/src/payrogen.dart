import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'exceptions.dart';
import 'models/environment.dart';
import 'models/escrow_result.dart';
import 'models/external_wallet.dart';
import 'models/fee_estimate.dart';
import 'models/payment_result.dart';
import 'models/recovery_result.dart';
import 'models/wallet.dart';
import 'models/withdrawal_result.dart';
import 'network_mismatch_validator.dart';
import 'secure_storage.dart';

/// Main entry point for the PayRogen SDK.
///
/// Provides wallet creation, direct payments, escrow payments, and wallet
/// recovery with no more than 3 method calls per operation.
///
/// Usage:
/// ```dart
/// final payrogen = await PayRogen.init(
///   apiKey: 'ck_live_...',
///   environment: PayRogenEnvironment.live,
/// );
///
/// final wallet = await payrogen.createWallet(userId: 'user123');
/// final payment = await payrogen.payDirect(
///   amount: 100.0,
///   currency: 'USDT',
///   from: wallet.publicAddress,
///   to: 'recipient_address',
///   splits: {'seller': 9000, 'platform': 1000},
/// );
/// ```
class PayRogen {
  final ApiClient _apiClient;
  final SecureShareStorage? _secureStorage;

  PayRogen._(this._apiClient, this._secureStorage);

  /// Initialize the PayRogen SDK with a merchant API key.
  ///
  /// Authenticates with the Gateway and caches the session for subsequent
  /// operations. (Requirement 9.2)
  ///
  /// [apiKey] - The merchant's API key (e.g., 'ck_live_...' or 'ck_sandbox_...').
  /// [environment] - The target environment (sandbox or live).
  /// [secureStorage] - Optional secure storage for Share_A. If provided,
  ///   Share_A will be automatically stored during wallet creation and
  ///   retrieved transparently during transaction signing. (Requirement 9.3)
  ///
  /// Throws [PayRogenAuthException] if authentication fails.
  /// Throws [PayRogenNetworkException] if the Gateway is unreachable.
  static Future<PayRogen> init({
    required String apiKey,
    PayRogenEnvironment environment = PayRogenEnvironment.live,
    SecureShareStorage? secureStorage,
  }) async {
    final apiClient = ApiClient(
      apiKey: apiKey,
      environment: environment,
    );

    await apiClient.authenticate();

    return PayRogen._(apiClient, secureStorage);
  }

  /// Initialize with a custom HTTP client (for testing).
  static Future<PayRogen> initWithClient({
    required String apiKey,
    required PayRogenEnvironment environment,
    required http.Client httpClient,
    SecureShareStorage? secureStorage,
  }) async {
    final apiClient = ApiClient(
      apiKey: apiKey,
      environment: environment,
      httpClient: httpClient,
    );

    await apiClient.authenticate();

    return PayRogen._(apiClient, secureStorage);
  }

  /// Create a non-custodial wallet for the given user.
  ///
  /// Generates a wallet via SSS on the Gateway, returning the public address
  /// and Share_A for device storage. If [SecureShareStorage] was provided
  /// during initialization, Share_A is automatically stored in platform-secure
  /// storage (iOS Keychain / Android Keystore). (Requirements 9.1, 9.3)
  ///
  /// [userId] - Unique identifier for the end user.
  ///
  /// Throws [PayRogenValidationException] if userId is empty.
  /// Throws [PayRogenException] on Gateway errors.
  Future<Wallet> createWallet({required String userId}) async {
    if (userId.isEmpty) {
      throw const PayRogenValidationException(
        message: 'userId must not be empty',
      );
    }

    final response = await _apiClient.post(
      '/v1/wallets/create',
      body: {'user_id': userId},
    );

    final wallet = Wallet.fromJson(response);

    // Auto-store Share_A in secure storage if configured (Requirement 9.3)
    final storage = _secureStorage;
    if (storage != null) {
      await storage.storeShareA(
        userId: userId,
        shareA: wallet.shareA,
      );
    }

    return wallet;
  }

  /// Execute a direct split payment.
  ///
  /// Sends a payment from one address to recipients according to the split
  /// configuration. All splits must sum to exactly 10000 basis points.
  /// (Requirement 9.1)
  ///
  /// Performs client-side network mismatch pre-flight validation before
  /// sending the request to the Gateway. If a mismatch is detected, throws
  /// [PayRogenNetworkMismatchException] with a clear warning message.
  /// (Requirement 32.9)
  ///
  /// [amount] - The total payment amount.
  /// [currency] - The currency/token to use (e.g., 'USDT', 'SOL').
  /// [from] - The payer's public wallet address.
  /// [to] - The primary receiver's public wallet address.
  /// [splits] - Map of recipient addresses to basis points (must sum to 10000).
  /// [sourceChain] - Optional source chain type for mismatch validation.
  ///   If provided, client-side network validation is performed.
  /// [idempotencyKey] - Optional idempotency key to prevent duplicate payments.
  /// [metadata] - Optional metadata to attach to the transaction.
  ///
  /// Throws [PayRogenNetworkMismatchException] if a network mismatch is detected.
  /// Throws [PayRogenValidationException] if parameters are invalid.
  /// Throws [PayRogenException] on Gateway errors.
  Future<PaymentResult> payDirect({
    required double amount,
    required String currency,
    required String from,
    required String to,
    required Map<String, int> splits,
    String? sourceChain,
    String? idempotencyKey,
    Map<String, String>? metadata,
  }) async {
    // Client-side network mismatch pre-flight validation (Requirement 32.9)
    if (sourceChain != null) {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: sourceChain,
        destinationAddress: to,
        tokenSymbol: currency,
      );
    }

    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'payer_address': from,
      'receiver_address': to,
      'splits': splits,
    };

    if (idempotencyKey != null) {
      body['idempotency_key'] = idempotencyKey;
    }
    if (metadata != null) {
      body['metadata'] = metadata;
    }

    final response = await _apiClient.post(
      '/v1/payments/direct',
      body: body,
    );

    return PaymentResult.fromJson(response);
  }

  /// Execute an escrow payment.
  ///
  /// Locks funds in an on-chain escrow PDA until delivery confirmation or
  /// timeout. Splits must sum to exactly 10000 basis points. (Requirement 9.1)
  ///
  /// Performs client-side network mismatch pre-flight validation before
  /// sending the request to the Gateway. If a mismatch is detected, throws
  /// [PayRogenNetworkMismatchException] with a clear warning message.
  /// (Requirement 32.9)
  ///
  /// [amount] - The total escrow amount.
  /// [currency] - The currency/token to use (e.g., 'USDT', 'SOL').
  /// [payer] - The buyer's public wallet address.
  /// [serviceProvider] - The seller/service provider's wallet address.
  /// [platform] - The merchant/platform's wallet address.
  /// [splits] - Map of recipient addresses to basis points (must sum to 10000).
  /// [sourceChain] - Optional source chain type for mismatch validation.
  ///   If provided, client-side network validation is performed.
  /// [idempotencyKey] - Optional idempotency key to prevent duplicate payments.
  /// [metadata] - Optional metadata to attach to the escrow.
  ///
  /// Throws [PayRogenNetworkMismatchException] if a network mismatch is detected.
  /// Throws [PayRogenValidationException] if parameters are invalid.
  /// Throws [PayRogenException] on Gateway errors.
  Future<EscrowResult> payEscrow({
    required double amount,
    required String currency,
    required String payer,
    required String serviceProvider,
    required String platform,
    required Map<String, int> splits,
    String? sourceChain,
    String? idempotencyKey,
    Map<String, String>? metadata,
  }) async {
    // Client-side network mismatch pre-flight validation (Requirement 32.9)
    if (sourceChain != null) {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: sourceChain,
        destinationAddress: serviceProvider,
        tokenSymbol: currency,
      );
    }

    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'payer_address': payer,
      'service_provider_address': serviceProvider,
      'platform_address': platform,
      'splits': splits,
    };

    if (idempotencyKey != null) {
      body['idempotency_key'] = idempotencyKey;
    }
    if (metadata != null) {
      body['metadata'] = metadata;
    }

    final response = await _apiClient.post(
      '/v1/payments/escrow',
      body: body,
    );

    return EscrowResult.fromJson(response);
  }

  /// Recover a wallet using a recovery phrase.
  ///
  /// Reconstructs wallet access using Share_B (Web3Auth) + Share_C (DB backup).
  /// If the phrase matches the stored duress phrase, a wallet freeze is
  /// triggered silently. (Requirement 9.1)
  ///
  /// After successful recovery, the new Share_A is automatically stored in
  /// secure storage if configured. (Requirement 9.3)
  ///
  /// [userId] - The user ID of the wallet to recover.
  /// [phrase] - The recovery phrase (or duress phrase to trigger freeze).
  ///
  /// Throws [PayRogenValidationException] if parameters are invalid.
  /// Throws [PayRogenException] on Gateway errors.
  Future<RecoveryResult> recoverWallet({
    required String userId,
    required String phrase,
  }) async {
    if (userId.isEmpty) {
      throw const PayRogenValidationException(
        message: 'userId must not be empty',
      );
    }
    if (phrase.isEmpty) {
      throw const PayRogenValidationException(
        message: 'phrase must not be empty',
      );
    }

    final response = await _apiClient.post(
      '/v1/wallets/recover',
      body: {
        'user_id': userId,
        'phrase': phrase,
      },
    );

    final result = RecoveryResult.fromJson(response);

    // Auto-store new Share_A in secure storage if configured (Requirement 9.3)
    final storage = _secureStorage;
    if (storage != null && result.success) {
      await storage.storeShareA(
        userId: userId,
        shareA: result.shareA,
      );
    }

    return result;
  }

  /// Retrieve Share_A for the given user from secure storage.
  ///
  /// This is used transparently during transaction signing to reconstruct
  /// the private key. (Requirement 9.3)
  ///
  /// [userId] - The user whose Share_A to retrieve.
  ///
  /// Returns `null` if no Share_A is stored or if secure storage was not
  /// configured during initialization.
  ///
  /// Throws [SecureStorageException] if the retrieval operation fails.
  Future<String?> getShareA({required String userId}) async {
    final storage = _secureStorage;
    if (storage == null) return null;
    return storage.retrieveShareA(userId: userId);
  }

  /// Create a non-custodial wallet for a specific blockchain.
  ///
  /// Generates a multi-chain wallet via SSS on the Gateway, using chain-appropriate
  /// key derivation (Ed25519 for Solana, secp256k1 for EVM/Bitcoin).
  /// (Requirement 28.7)
  ///
  /// [chainType] - The blockchain to create the wallet on (e.g., 'solana',
  ///   'ethereum', 'polygon', 'bitcoin').
  ///
  /// Throws [PayRogenValidationException] if chainType is empty or unsupported.
  /// Throws [PayRogenException] on Gateway errors.
  Future<Wallet> createMultiChainWallet({required String chainType}) async {
    if (chainType.isEmpty) {
      throw const PayRogenValidationException(
        message: 'chainType must not be empty',
      );
    }

    final response = await _apiClient.post(
      '/v1/wallets/create',
      body: {'chain_type': chainType},
    );

    final wallet = Wallet.fromJson(response);

    // Auto-store Share_A in secure storage if configured (Requirement 9.3)
    final storage = _secureStorage;
    if (storage != null) {
      await storage.storeShareA(
        userId: wallet.userId,
        shareA: wallet.shareA,
      );
    }

    return wallet;
  }

  /// Register an external wallet address as a trusted withdrawal destination.
  ///
  /// The address will be subject to an Address_Cooldown period (default 24 hours)
  /// before it can be used for withdrawals. (Requirement 29.7)
  ///
  /// [label] - User-defined label (e.g., "Binance Hot Wallet").
  /// [address] - The blockchain address to register.
  /// [chainType] - The chain type (e.g., 'solana', 'ethereum', 'bitcoin').
  ///
  /// Throws [PayRogenValidationException] if any parameter is empty.
  /// Throws [PayRogenException] on Gateway errors (e.g., invalid address format).
  Future<ExternalWallet> addExternalWallet({
    required String label,
    required String address,
    required String chainType,
  }) async {
    if (label.isEmpty) {
      throw const PayRogenValidationException(
        message: 'label must not be empty',
      );
    }
    if (address.isEmpty) {
      throw const PayRogenValidationException(
        message: 'address must not be empty',
      );
    }
    if (chainType.isEmpty) {
      throw const PayRogenValidationException(
        message: 'chainType must not be empty',
      );
    }

    final response = await _apiClient.post(
      '/v1/external-wallets',
      body: {
        'label': label,
        'address': address,
        'chain_type': chainType,
      },
    );

    return ExternalWallet.fromJson(response);
  }

  /// List all registered external wallets with their cooldown status.
  ///
  /// Returns a list of [ExternalWallet] entries showing label, address,
  /// chain type, and whether the cooldown period has elapsed. (Requirement 29.7)
  ///
  /// Throws [PayRogenException] on Gateway errors.
  Future<List<ExternalWallet>> listExternalWallets() async {
    final response = await _apiClient.get('/v1/external-wallets');

    final wallets = (response['external_wallets'] as List<dynamic>)
        .map((e) => ExternalWallet.fromJson(e as Map<String, dynamic>))
        .toList();

    return wallets;
  }

  /// Remove an external wallet from the address book.
  ///
  /// Removal is immediate without a cooldown period. (Requirement 29.4)
  ///
  /// [walletId] - The unique ID of the external wallet to remove.
  ///
  /// Throws [PayRogenValidationException] if walletId is empty.
  /// Throws [PayRogenException] on Gateway errors.
  Future<void> removeExternalWallet({required String walletId}) async {
    if (walletId.isEmpty) {
      throw const PayRogenValidationException(
        message: 'walletId must not be empty',
      );
    }

    await _apiClient.delete('/v1/external-wallets/$walletId');
  }

  /// Initiate a withdrawal to a whitelisted external wallet.
  ///
  /// Handles key reconstruction (Share_A + Share_B), transaction signing,
  /// and submission transparently. The destination must have passed its
  /// Address_Cooldown period. (Requirement 30.9)
  ///
  /// [externalWalletId] - The ID of the whitelisted destination address.
  /// [amount] - The amount to withdraw.
  /// [tokenSymbol] - The token to withdraw (e.g., 'USDT', 'SOL', 'ETH').
  ///
  /// Throws [PayRogenValidationException] if parameters are invalid.
  /// Throws [PayRogenException] on Gateway errors (cooldown not elapsed,
  ///   insufficient balance, wallet frozen, etc.).
  Future<WithdrawalResult> withdraw({
    required String externalWalletId,
    required double amount,
    required String tokenSymbol,
  }) async {
    if (externalWalletId.isEmpty) {
      throw const PayRogenValidationException(
        message: 'externalWalletId must not be empty',
      );
    }
    if (amount <= 0) {
      throw const PayRogenValidationException(
        message: 'amount must be greater than 0',
      );
    }
    if (tokenSymbol.isEmpty) {
      throw const PayRogenValidationException(
        message: 'tokenSymbol must not be empty',
      );
    }

    final response = await _apiClient.post(
      '/v1/withdrawals',
      body: {
        'external_wallet_id': externalWalletId,
        'amount': amount,
        'token_symbol': tokenSymbol,
      },
    );

    return WithdrawalResult.fromJson(response);
  }

  /// Estimate the network fee for a withdrawal.
  ///
  /// Returns the estimated gas/network fee, amount after fees, and
  /// estimated confirmation time for the specified chain and token.
  /// (Requirement 31.8)
  ///
  /// [chainType] - The chain for the withdrawal (e.g., 'solana', 'ethereum').
  /// [token] - The token symbol (e.g., 'USDT', 'SOL').
  /// [amount] - The withdrawal amount to estimate fees for.
  ///
  /// Throws [PayRogenValidationException] if parameters are invalid.
  /// Throws [PayRogenException] on Gateway errors.
  Future<FeeEstimate> estimateWithdrawalFee({
    required String chainType,
    required String token,
    required double amount,
  }) async {
    if (chainType.isEmpty) {
      throw const PayRogenValidationException(
        message: 'chainType must not be empty',
      );
    }
    if (token.isEmpty) {
      throw const PayRogenValidationException(
        message: 'token must not be empty',
      );
    }
    if (amount <= 0) {
      throw const PayRogenValidationException(
        message: 'amount must be greater than 0',
      );
    }

    final response = await _apiClient.get(
      '/v1/withdrawals/fee-estimate?chain_type=$chainType&token=$token&amount=$amount',
    );

    return FeeEstimate.fromJson(response);
  }

  /// Validate network consistency before submitting a payment or withdrawal.
  ///
  /// This is a convenience method that exposes the client-side network mismatch
  /// pre-flight validation. Use it to check for chain mismatches before
  /// building payment UIs or confirmation screens.
  ///
  /// [sourceChain] - The chain type of the source wallet (e.g., 'solana',
  ///   'ethereum', 'polygon', 'bitcoin').
  /// [destinationAddress] - The destination address to validate.
  /// [tokenSymbol] - The token being sent (e.g., 'USDT', 'SOL').
  ///
  /// Throws [PayRogenNetworkMismatchException] if a mismatch is detected
  /// with a user-friendly message explaining the issue and how to fix it.
  /// (Requirement 32.9)
  void validateNetworkConsistency({
    required String sourceChain,
    required String destinationAddress,
    required String tokenSymbol,
  }) {
    NetworkMismatchValidator.validateNetworkConsistency(
      sourceChain: sourceChain,
      destinationAddress: destinationAddress,
      tokenSymbol: tokenSymbol,
    );
  }

  /// Close the SDK and release resources.
  void dispose() {
    _apiClient.close();
  }
}
