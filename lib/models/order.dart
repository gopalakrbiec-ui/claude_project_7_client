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
  final String status; // pending | processing | completed | failed
  final String templateId;
  final int pricePaise;
  final String priceDisplay;
  final String? resultUrl;
  final DateTime createdAt;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending' || status == 'processing';

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        status: json['status'] as String,
        templateId: json['template_id'] as String,
        pricePaise: json['price_paise'] as int,
        priceDisplay: json['price_display'] as String,
        resultUrl: json['result_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
