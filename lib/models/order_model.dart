import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/utils/date_parser.dart';

@immutable
class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String? variantId;
  final String? variantNameSnapshot;
  final String productNameSnapshot;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    this.variantId,
    this.variantNameSnapshot,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  String get formattedUnitPrice => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(unitPrice);

  String get formattedSubtotal => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(subtotal);

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      variantId: map['variantId']?.toString(),
      variantNameSnapshot: map['variantNameSnapshot']?.toString(),
      productNameSnapshot: map['productNameSnapshot']?.toString() ?? 'Item',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] is num)
          ? (map['unitPrice'] as num).toDouble()
          : double.tryParse(map['unitPrice']?.toString() ?? '0') ?? 0.0,
      subtotal: (map['subtotal'] is num)
          ? (map['subtotal'] as num).toDouble()
          : double.tryParse(map['subtotal']?.toString() ?? '0') ?? 0.0,
      notes: map['notes']?.toString(),
    );
  }
}

@immutable
class PaymentModel {
  final String id;
  final String orderId;
  final String shiftId;
  final String method; // 'CASH' | 'QRIS'
  final String status; // 'PAID' | 'PENDING'
  final double amount;
  final double? cashReceived;
  final double? changeAmount;
  final DateTime? paidAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.shiftId,
    required this.method,
    required this.status,
    required this.amount,
    this.cashReceived,
    this.changeAmount,
    this.paidAt,
  });

  String get formattedAmount => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);

  String get formattedCashReceived => cashReceived != null
      ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(cashReceived!)
      : '-';

  String get formattedChangeAmount => changeAmount != null
      ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(changeAmount!)
      : '-';

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      shiftId: map['shiftId']?.toString() ?? '',
      method: map['method']?.toString() ?? 'CASH',
      status: map['status']?.toString() ?? 'PAID',
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      cashReceived: map['cashReceived'] != null
          ? ((map['cashReceived'] as num?)?.toDouble() ??
              double.tryParse(map['cashReceived'].toString()))
          : null,
      changeAmount: map['changeAmount'] != null
          ? ((map['changeAmount'] as num?)?.toDouble() ??
              double.tryParse(map['changeAmount'].toString()))
          : null,
      paidAt: map['paidAt'] != null
          ? DateTime.tryParse(map['paidAt'].toString())
          : null,
    );
  }
}

@immutable
class OrderModel {
  final String id;
  final String storeId;
  final String? createdById;
  final String orderNumber;
  final String? queueNumber;
  final String source;
  final String status;
  final String? publicQrToken;
  final String? customerId;
  final String customerNameSnapshot;
  final String? customerPhoneSnapshot;
  final double productSubtotal;
  final double promotionDiscount;
  final double taxableSubtotal;
  final double grandTotal;
  final double cashPayable;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  final PaymentModel? payment;
  final String? promoCodeSnapshot;
  final String? cashierName;

  const OrderModel({
    required this.id,
    required this.storeId,
    this.createdById,
    required this.orderNumber,
    this.queueNumber,
    this.source = 'POS',
    this.status = 'PAID',
    this.publicQrToken,
    this.customerId,
    required this.customerNameSnapshot,
    this.customerPhoneSnapshot,
    required this.productSubtotal,
    this.promotionDiscount = 0,
    this.promoCodeSnapshot,
    required this.taxableSubtotal,
    required this.grandTotal,
    required this.cashPayable,
    this.expiresAt,
    this.paidAt,
    required this.createdAt,
    this.items = const [],
    this.payment,
    this.cashierName,
  });

  String get formattedGrandTotal => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(grandTotal);

  String get formattedDate {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(createdAt);
    } catch (_) {
      return DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
    }
  }

  String get formattedTime {
    try {
      return DateFormat('HH:mm', 'id_ID').format(createdAt);
    } catch (_) {
      return DateFormat('HH:mm').format(createdAt);
    }
  }

  bool get isDineIn =>
      (queueNumber?.startsWith('D') ?? false) ||
      (queueNumber?.startsWith('A') ?? false);
  String get diningLabel => isDineIn ? 'Dine-in' : 'Takeaway';

  int get minutesLeft {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.toLocal().difference(DateTime.now()).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.toLocal());
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    // Parse order items
    final List<OrderItemModel> itemsList = [];
    final rawItems = map['items'] ?? map['OrderItem'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(OrderItemModel.fromMap(item));
        }
      }
    }

    // Parse payment
    PaymentModel? paymentObj;
    final rawPayment = map['payment'] ?? map['Payment'];
    if (rawPayment is Map<String, dynamic>) {
      paymentObj = PaymentModel.fromMap(rawPayment);
    } else if (rawPayment is List && rawPayment.isNotEmpty) {
      paymentObj = PaymentModel.fromMap(rawPayment.first as Map<String, dynamic>);
    }

    // Parse cashier name
    String? cashierName;
    final userData = map['createdBy'] ?? map['User'];
    if (userData is Map<String, dynamic>) {
      cashierName = userData['name']?.toString() ?? userData['username']?.toString();
    }

    // Parse promo code
    String? promoCode = map['promoCodeSnapshot']?.toString();
    if (promoCode == null && map['OrderPromotion'] is List && (map['OrderPromotion'] as List).isNotEmpty) {
      promoCode = (map['OrderPromotion'] as List).first['promotionCodeSnapshot']?.toString();
    }

    return OrderModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      createdById: map['createdById']?.toString(),
      orderNumber: map['orderNumber']?.toString() ?? '',
      queueNumber: map['queueNumber']?.toString(),
      source: map['source']?.toString() ?? 'POS',
      status: map['status']?.toString() ?? 'PAID',
      publicQrToken: map['publicQrToken']?.toString(),
      customerId: map['customerId']?.toString(),
      customerNameSnapshot: map['customerNameSnapshot']?.toString() ?? 'Pelanggan',
      customerPhoneSnapshot: map['customerPhoneSnapshot']?.toString(),
      productSubtotal: (map['productSubtotal'] is num)
          ? (map['productSubtotal'] as num).toDouble()
          : double.tryParse(map['productSubtotal']?.toString() ?? '0') ?? 0.0,
      promotionDiscount: (map['promotionDiscount'] is num)
          ? (map['promotionDiscount'] as num).toDouble()
          : double.tryParse(map['promotionDiscount']?.toString() ?? '0') ?? 0.0,
      promoCodeSnapshot: promoCode,
      taxableSubtotal: (map['taxableSubtotal'] is num)
          ? (map['taxableSubtotal'] as num).toDouble()
          : double.tryParse(map['taxableSubtotal']?.toString() ?? '0') ?? 0.0,
      grandTotal: (map['grandTotal'] is num)
          ? (map['grandTotal'] as num).toDouble()
          : double.tryParse(map['grandTotal']?.toString() ?? '0') ?? 0.0,
      cashPayable: (map['cashPayable'] is num)
          ? (map['cashPayable'] as num).toDouble()
          : double.tryParse(map['cashPayable']?.toString() ?? '0') ?? 0.0,
      expiresAt: tryParseDateTime(map['expiresAt']),
      paidAt: tryParseDateTime(map['paidAt']),
      createdAt: parseDateTime(map['createdAt']),
      items: itemsList,
      payment: paymentObj,
      cashierName: cashierName,
    );
  }
}
