import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class ProductCategory {
  final String id;
  final String storeId;
  final String name;

  const ProductCategory({
    required this.id,
    required this.storeId,
    required this.name,
  });

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}

@immutable
class ProductVariantModel {
  final String id;
  final String productId;
  final String name;
  final String? sku;
  final double price;
  final String availability; // 'AVAILABLE' | 'OUT_OF_STOCK'
  final bool discontinued;

  const ProductVariantModel({
    required this.id,
    required this.productId,
    required this.name,
    this.sku,
    required this.price,
    this.availability = 'AVAILABLE',
    this.discontinued = false,
  });

  bool get isAvailable => availability == 'AVAILABLE' && !discontinued;

  String get formattedPrice {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(price);
  }

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    return ProductVariantModel(
      id: map['id']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString(),
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      availability: map['availability']?.toString() ?? 'AVAILABLE',
      discontinued: map['discontinued'] == true,
    );
  }
}

@immutable
class ProductModel {
  final String id;
  final String storeId;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? sku;
  final String? imageUrl;
  final String type; // 'RECIPE' | 'DIRECT_STOCK'
  final double price;
  final String availability; // 'AVAILABLE' | 'OUT_OF_STOCK'
  final bool discontinued;
  final List<ProductVariantModel> variants;

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.sku,
    this.imageUrl,
    this.type = 'RECIPE',
    required this.price,
    this.availability = 'AVAILABLE',
    this.discontinued = false,
    this.variants = const [],
  });

  bool get hasVariants => variants.isNotEmpty;
  bool get isAvailable => availability == 'AVAILABLE' && !discontinued;

  String get formattedPrice {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(price);
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // Parse nested category if available
    String? categoryName;
    final catData = map['category'] ?? map['ProductCategory'];
    if (catData is Map<String, dynamic>) {
      categoryName = catData['name']?.toString();
    }

    // Parse nested variants
    final List<ProductVariantModel> variantsList = [];
    final variantsData = map['variants'] ?? map['ProductVariant'];
    if (variantsData is List) {
      for (final v in variantsData) {
        if (v is Map<String, dynamic>) {
          final variant = ProductVariantModel.fromMap(v);
          if (!variant.discontinued) {
            variantsList.add(variant);
          }
        }
      }
    }

    return ProductModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      categoryId: map['categoryId']?.toString() ?? '',
      categoryName: categoryName,
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      type: map['type']?.toString() ?? 'RECIPE',
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      availability: map['availability']?.toString() ?? 'AVAILABLE',
      discontinued: map['discontinued'] == true,
      variants: variantsList,
    );
  }
}
