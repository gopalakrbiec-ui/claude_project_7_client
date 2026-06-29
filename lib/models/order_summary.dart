/// Lightweight order item returned by GET /orders list.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.status,
    required this.pricePaise,
    this.templateName,
    this.resultUrl,
    this.createdAt,
  });

  final String id;
  final String status;
  final int pricePaise;
  final String? templateName;
  final String? resultUrl;
  final DateTime? createdAt;

  bool get isDone => status == 'done' || status == 'completed';
  bool get isInProgress =>
      status == 'queued' ||
      status == 'pending' ||
      status == 'moderating' ||
      status == 'generating' ||
      status == 'processing';
  bool get isFailed => status == 'failed' || status == 'rejected';

  String get priceDisplay {
    final r = pricePaise / 100;
    return r == r.truncateToDouble() ? '₹${r.toInt()}' : '₹${r.toStringAsFixed(2)}';
  }

  String get statusLabel => switch (status) {
        'queued' => 'In queue',
        'moderating' => 'Reviewing',
        'generating' => 'Generating',
        'done' || 'completed' => 'Done',
        'rejected' || 'failed' => 'Failed',
        _ => status,
      };

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'].toString(),
        status: (json['status'] as String?) ?? 'queued',
        pricePaise: (json['price_paise'] as num?)?.toInt() ?? 0,
        templateName: json['template_name'] as String?,
        resultUrl: json['result_url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class OrderListPage {
  const OrderListPage({
    required this.orders,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<OrderSummary> orders;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => orders.length < total;

  factory OrderListPage.fromJson(Map<String, dynamic> json) => OrderListPage(
        orders: (json['orders'] as List<dynamic>? ?? [])
            .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );
}
