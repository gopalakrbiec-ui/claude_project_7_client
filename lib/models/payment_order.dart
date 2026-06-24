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
        paymentId: json['payment_id'] as String,
        gatewayOrderId: json['gateway_order_id'] as String,
        amountPaise: json['amount_paise'] as int,
        currency: json['currency'] as String,
        keyId: json['key_id'] as String,
      );
}
