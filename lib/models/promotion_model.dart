import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/utils/date_parser.dart';

@immutable
class PromotionModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final int? usageLimit;
  final int usageCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String discountType; // 'PERCENTAGE' | 'FIXED'
  final double discountValue;
  final double? maxDiscount;
  final String discountScope; // 'ORDER' | 'PRODUCT'
  final double? minimumPurchase;
  final String? targetProductId;
  final String? targetProductName;

  const PromotionModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.usageLimit,
    this.usageCount = 0,
    this.startDate,
    this.endDate,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    this.discountScope = 'ORDER',
    this.minimumPurchase,
    this.targetProductId,
    this.targetProductName,
  });

  bool get isPercentage => discountType == 'PERCENTAGE';
  bool get isProductScope => discountScope == 'PRODUCT';

  String get formattedDiscountBadge {
    if (isPercentage) {
      final pct = discountValue % 1 == 0
          ? discountValue.toInt().toString()
          : discountValue.toStringAsFixed(1);
      return 'Diskon $pct%';
    } else {
      final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return 'Potongan ${f.format(discountValue)}';
    }
  }

  String? get formattedMaxDiscount {
    if (maxDiscount != null && maxDiscount! > 0) {
      final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return 'Maks. ${f.format(maxDiscount!)}';
    }
    return null;
  }

  String? get formattedMinPurchase {
    if (minimumPurchase != null && minimumPurchase! > 0) {
      final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return 'Min. Belanja ${f.format(minimumPurchase!)}';
    }
    return null;
  }

  factory PromotionModel.fromMap(Map<dynamic, dynamic> rawMap) {
    Map<String, dynamic>? toMap(dynamic val) {
      if (val == null) return null;
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    }

    Map<String, dynamic>? firstMap(dynamic val) {
      if (val == null) return null;
      if (val is Map) return toMap(val);
      if (val is List && val.isNotEmpty) return toMap(val.first);
      return null;
    }

    final map = toMap(rawMap) ?? <String, dynamic>{};

    // 1. Ekstrak data action diskon (bisa Map atau List dari Supabase PostgREST)
    final actionMap = firstMap(map['discountAction']);

    final rawType = actionMap?['type']?.toString() ??
        map['discountType']?.toString() ??
        'PERCENTAGE';
    final dType =
        rawType.toUpperCase().contains('PERCENT') ? 'PERCENTAGE' : 'FIXED';
    final dScope = actionMap?['scope']?.toString() ??
        map['discountScope']?.toString() ??
        'ORDER';
    final dValue = (actionMap?['value'] is num)
        ? (actionMap!['value'] as num).toDouble()
        : double.tryParse(actionMap?['value']?.toString() ??
                map['discountValue']?.toString() ??
                '0') ??
            0.0;
    final maxDisc = (actionMap?['maxDiscount'] is num)
        ? (actionMap!['maxDiscount'] as num).toDouble()
        : double.tryParse(actionMap?['maxDiscount']?.toString() ??
            map['maxDiscount']?.toString() ??
            '');

    // 2. Ekstrak data condition group & conditions (bisa Map atau List)
    final groupMap = firstMap(map['conditionGroup']);

    List<dynamic> conditionList = [];
    final rawConds = groupMap?['conditions'] ?? map['conditions'];
    if (rawConds is List) {
      conditionList = rawConds;
    }

    double? minPurchase;
    String? targetProdId;
    String? targetProdName;

    for (final rawC in conditionList) {
      final c = toMap(rawC);
      if (c != null) {
        final cType = c['type']?.toString();
        if (cType == 'MINIMUM_PURCHASE') {
          minPurchase = (c['minimumPurchase'] is num)
              ? (c['minimumPurchase'] as num).toDouble()
              : double.tryParse(c['minimumPurchase']?.toString() ?? '');
        } else if (cType == 'PRODUCT') {
          targetProdId = c['productId']?.toString();
          final prod = toMap(c['product']);
          if (prod != null) {
            targetProdName = prod['name']?.toString();
          }
        }
      }
    }

    return PromotionModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      description: map['description']?.toString(),
      usageLimit: (map['usageLimit'] as num?)?.toInt(),
      usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
      startDate: tryParseDateTime(map['startAt'] ?? map['startDate']),
      endDate: tryParseDateTime(map['endAt'] ?? map['endDate']),
      discountType: dType,
      discountValue: dValue,
      maxDiscount: maxDisc,
      discountScope: dScope,
      minimumPurchase: minPurchase,
      targetProductId: targetProdId,
      targetProductName: targetProdName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      if (description != null) 'description': description,
      if (usageLimit != null) 'usageLimit': usageLimit,
      'usageCount': usageCount,
      if (startDate != null) 'startDate': startDate!.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toUtc().toIso8601String(),
      'discountType': discountType,
      'discountValue': discountValue,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      'discountScope': discountScope,
      if (minimumPurchase != null) 'minimumPurchase': minimumPurchase,
      if (targetProductId != null) 'targetProductId': targetProductId,
      if (targetProductName != null) 'targetProductName': targetProductName,
    };
  }

  PromotionModel copyWith({
    String? id,
    String? name,
    String? code,
    String? Function()? description,
    int? Function()? usageLimit,
    int? usageCount,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    String? discountType,
    double? discountValue,
    double? Function()? maxDiscount,
    String? discountScope,
    double? Function()? minimumPurchase,
    String? Function()? targetProductId,
    String? Function()? targetProductName,
  }) {
    return PromotionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description != null ? description() : this.description,
      usageLimit: usageLimit != null ? usageLimit() : this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxDiscount: maxDiscount != null ? maxDiscount() : this.maxDiscount,
      discountScope: discountScope ?? this.discountScope,
      minimumPurchase: minimumPurchase != null ? minimumPurchase() : this.minimumPurchase,
      targetProductId: targetProductId != null ? targetProductId() : this.targetProductId,
      targetProductName: targetProductName != null ? targetProductName() : this.targetProductName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromotionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}

/// Hasil evaluasi kelayakan promo terhadap keranjang kasir
@immutable
class PromoEvaluationResult {
  final bool isEligible;
  final List<String> missingRequirements;
  final double estimatedDiscount;

  const PromoEvaluationResult({
    required this.isEligible,
    required this.missingRequirements,
    required this.estimatedDiscount,
  });

  String get formattedEstimatedDiscount => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(estimatedDiscount);
}
