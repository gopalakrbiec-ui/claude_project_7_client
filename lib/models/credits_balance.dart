/// Mirror of GET /credits/balance response schema.
class CreditsBalance {
  const CreditsBalance({
    required this.balancePaise,
    required this.balanceCoins,
  });

  /// Raw paise — use only for affordability checks (>= price_paise).
  final int balancePaise;

  /// Already-computed coin count from the server (balance_coins field).
  final int balanceCoins;

  bool canAfford(int pricePaise) => balancePaise >= pricePaise;

  /// "1000 🪙" — pass the symbol from currencyInfoProvider.
  String coinsDisplay(String symbol) => '$balanceCoins $symbol';

  factory CreditsBalance.fromJson(Map<String, dynamic> json) => CreditsBalance(
        balancePaise: (json['balance_paise'] as num?)?.toInt() ?? 0,
        // balance_coins is authoritative; fall back to paise ÷ 100.
        balanceCoins: (json['balance_coins'] as num?)?.toInt() ??
            ((json['balance_paise'] as num?)?.toInt() ?? 0) ~/ 100,
      );
}
