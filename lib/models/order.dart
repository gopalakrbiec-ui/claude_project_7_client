/// Mirror of GET /orders/{id} response schema.
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.templateId,
    required this.pricePaise,
    required this.priceDisplay,
    this.resultUrl,
    required this.createdAt,
  });

  final String id;

  /// Real API statuses: queued | moderating | generating | done | rejected
  /// Legacy compat statuses: pending | processing | completed | failed
  final String status;

  final String templateId;
  final int pricePaise;
  final String priceDisplay;

  /// Watermarked result URL — present when status == 'done'.
  final String? resultUrl;

  final DateTime createdAt;

  // -- Status helpers -------------------------------------------------------

  /// True while the backend is still working on the order.
  bool get isInProgress =>
      status == 'queued' ||
      status == 'moderating' ||
      status == 'generating' ||
      // legacy statuses for backwards compat
      status == 'pending' ||
      status == 'processing';

  bool get isDone => status == 'done' || status == 'completed';

  /// Content was rejected by the moderation step; credits are refunded.
  bool get isRejected => status == 'rejected' || status == 'failed';

  // Legacy aliases kept so existing CreateOrderController code compiles.
  bool get isCompleted => isDone;
  bool get isFailed => isRejected;
  bool get isPending => isInProgress;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'].toString(),
        status: (json['status'] as String?) ?? 'queued',
        templateId: json['template_id'].toString(),
        pricePaise: (json['price_paise'] as num?)?.toInt() ?? 0,
        // price_display may be absent on freshly created orders.
        priceDisplay: (json['price_display'] as String?) ?? '',
        resultUrl: json['result_url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}
