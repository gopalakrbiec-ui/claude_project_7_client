/// A single commission credit earned by the agent for placing an order.
class CommissionEntry {
  const CommissionEntry({
    required this.id,
    required this.orderId,
    required this.amountPaise,
    required this.amountDisplay,
    this.customerName,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final int amountPaise;

  /// Pre-formatted by the server (e.g. "₹5.00"). Never divide by 100 here.
  final String amountDisplay;
  final String? customerName;
  final DateTime createdAt;

  factory CommissionEntry.fromJson(Map<String, dynamic> json) =>
      CommissionEntry(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        amountPaise: json['amount_paise'] as int,
        amountDisplay: json['amount_display'] as String,
        customerName: json['customer_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Aggregate response from GET /agents/me/earnings.
class AgentEarnings {
  const AgentEarnings({
    required this.totalCommissionPaise,
    required this.totalCommissionDisplay,
    required this.entries,
  });

  final int totalCommissionPaise;

  /// Pre-formatted total (e.g. "₹150.00"). Never divide by 100 here.
  final String totalCommissionDisplay;

  final List<CommissionEntry> entries;

  factory AgentEarnings.fromJson(Map<String, dynamic> json) => AgentEarnings(
        totalCommissionPaise: json['total_commission_paise'] as int,
        totalCommissionDisplay: json['total_commission_display'] as String,
        entries: (json['entries'] as List<dynamic>)
            .map((e) => CommissionEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
