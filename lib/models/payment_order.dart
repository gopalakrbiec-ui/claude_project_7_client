/// Response from POST /payments/create-order.
/// key_id comes from the server — the client NEVER hardcodes a Razorpay key.
class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.gatewayOrderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });

  final String paymentId;
  final String gatewayOrderId; // passed to Razorpay as order_id
  final int amountPaise;       // passed to Razorpay as amount
  final String currency;       // e.g. "INR"
  final String keyId;          // Razorpay key — use this, never a hardcoded key

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        paymentId: (json['payment_id'] ?? json['id'] ?? '').toString(),
        gatewayOrderId: (json['gateway_order_id'] ?? json['order_id'] ?? '').toString(),
        amountPaise: _parseInt(json['amount_paise'] ?? json['amount']),
        currency: (json['currency'] ?? 'INR').toString(),
        keyId: (json['key_id'] ?? json['razorpay_key'] ?? '').toString(),
      );

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
