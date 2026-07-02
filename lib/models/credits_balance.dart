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
        balanceRupees: _toRupees(json['balance_rupees']),
      );

  /// Normalises any server-returned currency string to ₹ prefix.
  /// Handles: "₹12.50", "$12.50", "12.50", "Rs.12.50", etc.
  static String _toRupees(dynamic raw) {
    final s = (raw?.toString() ?? '0').trim();
    if (s.startsWith('₹')) return s;
    // Strip any leading non-digit characters (currency symbols, "Rs.", etc.)
    final digits = s.replaceFirst(RegExp(r'^[^\d]+'), '');
    return '₹$digits';
  }
}
