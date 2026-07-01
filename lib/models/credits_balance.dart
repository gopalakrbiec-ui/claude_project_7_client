/// Mirror of GET /credits/balance response schema.
/// Replace with generated model once `make gen-api` has run.
class CreditsBalance {
  const CreditsBalance({
    required this.balancePaise,
    required this.balanceRupees,
  });

  /// Raw value — use only for logic (e.g. checking affordability).
  final int balancePaise;

  /// Pre-formatted display string from the server (e.g. "₹12.50").
  /// Always display this. NEVER divide balancePaise by 100 yourself.
  final String balanceRupees;

  bool canAfford(int pricePaise) => balancePaise >= pricePaise;

  factory CreditsBalance.fromJson(Map<String, dynamic> json) => CreditsBalance(
        balancePaise: json['balance_paise'] as int,
        balanceRupees: (json['balance_rupees'] as String).replaceFirst(r'$', '₹'),
      );
}
