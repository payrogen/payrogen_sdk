/// The environment for PayRogen API operations.
///
/// Determines which backend servers and blockchain networks are used.
enum PayRogenEnvironment {
  /// Sandbox environment using Solana Devnet and test tokens.
  /// Use this for development and testing — no real funds are involved.
  sandbox,

  /// Live production environment using Solana Mainnet.
  /// Real transactions with real funds. Use only in production builds.
  live,
}
