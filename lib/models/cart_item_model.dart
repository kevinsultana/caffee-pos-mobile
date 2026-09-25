import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum DiningOption {
  dineIn,
  takeaway,
}

extension DiningOptionExt on DiningOption {
  String get label {
    switch (this) {
      case DiningOption.dineIn:
        return 'Dine-in (Makan di Tempat)';
      case DiningOption.takeaway:
        return 'Takeaway (Bungkus)';
    }
  }

  String get shortCode {
    switch (this) {
      case DiningOption.dineIn:
        return 'D'; // Kode antrean dine-in (D-XXX)
      case DiningOption.takeaway:
        return 'T'; // Kode antrean takeaway (T-XXX)
    }
  }
}

@immutable
class CartItemModel {
  final String id; // Kunci gabungan unik: "$productId-${variantId ?? 'default'}-${notes ?? ''}"
  final String productId;
  final String productName;
  final String? productImageUrl;
  final String? variantId;
  final String? variantName;
  final double unitPrice;
  final int quantity;
  final String? notes;

  const CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    this.variantId,
    this.variantName,
    required this.unitPrice,
    required this.quantity,
    this.notes,
  });

  double get subtotal => unitPrice * quantity;

  String get formattedSubtotal {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(subtotal);
  }

  String get formattedUnitPrice {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(unitPrice);
  }

  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImageUrl,
    String? variantId,
    String? variantName,
    double? unitPrice,
    int? quantity,
    String? notes,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      variantId: variantId ?? this.variantId,
      variantName: variantName ?? this.variantName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}
