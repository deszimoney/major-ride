import 'dart:convert';

import '../../config/app_config.dart';

/// Everything the Paystack popup needs for one transaction.
class PaystackRequest {
  const PaystackRequest({
    required this.email,
    required this.amount,
    required this.customerName,
    required this.collectionMethod,
    required this.deliveryLocation,
  });

  final String email;

  /// Cedis. Converted to pesewas in [amountInSubunits], as cart.js does.
  final double amount;
  final String customerName;
  final String collectionMethod;
  final String deliveryLocation;

  int get amountInSubunits => (amount * 100).round();

  Map<String, dynamic> toPopupOptions() => {
    'key': AppConfig.paystackPublicKey,
    'email': email,
    'amount': amountInSubunits,
    'currency': AppConfig.currency,
    'channels': ['card', 'bank', 'mobile_money'],
    'metadata': {
      'custom_fields': [
        {
          'display_name': 'Customer name',
          'variable_name': 'customer_name',
          'value': customerName,
        },
        {
          'display_name': 'Collection method',
          'variable_name': 'collection_method',
          'value': collectionMethod,
        },
        {
          'display_name': 'Delivery location',
          'variable_name': 'delivery_location',
          'value': deliveryLocation.isEmpty ? 'Pickup' : deliveryLocation,
        },
      ],
    },
  };

  /// Same shape as [toPopupOptions], serialised for `JSON.parse` on the web
  /// platform (see paystack_checkout_web.dart).
  String toPopupOptionsJson() => jsonEncode(toPopupOptions());
}

enum PaystackStatus { success, cancelled, error }

/// Result of a checkout attempt, matching the popup's three callbacks.
class PaystackResult {
  const PaystackResult.success(this.reference)
    : status = PaystackStatus.success,
      message = null;

  const PaystackResult.cancelled()
    : status = PaystackStatus.cancelled,
      reference = null,
      message = 'Payment was cancelled. Your cart is still available.';

  const PaystackResult.error(this.message)
    : status = PaystackStatus.error,
      reference = null;

  final PaystackStatus status;
  final String? reference;
  final String? message;

  bool get isSuccess => status == PaystackStatus.success;
}
