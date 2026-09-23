import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Tipe pergerakan kas dalam shift
enum CashMovementType {
  cashIn,
  cashOut;

  /// Nilai string sesuai skema Supabase/Prisma
  String get value => switch (this) {
        CashMovementType.cashIn => 'CASH_IN',
        CashMovementType.cashOut => 'CASH_OUT',
      };

  static CashMovementType fromString(String? value) {
    return switch (value?.toUpperCase()) {
      'CASH_IN' => CashMovementType.cashIn,
      _ => CashMovementType.cashOut,
    };
  }
}

@immutable
class CashMovementModel {
  final String id;
  final String storeId;
  final String shiftId;
  final String userId;
  final CashMovementType type;
  final double amount;
  final String reason;
  final DateTime createdAt;

  const CashMovementModel({
    required this.id,
    required this.storeId,
    required this.shiftId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  bool get isCashIn => type == CashMovementType.cashIn;
  bool get isCashOut => type == CashMovementType.cashOut;

  String get formattedAmount {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return fmt.format(amount);
  }

  String get formattedTime {
    try {
      return DateFormat('dd MMM, HH:mm', 'id_ID').format(createdAt.toLocal());
    } catch (_) {
      return DateFormat('dd MMM, HH:mm').format(createdAt.toLocal());
    }
  }

  factory CashMovementModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(map['createdAt'].toString()).toLocal();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return CashMovementModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      shiftId: map['shiftId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      type: CashMovementType.fromString(map['type']?.toString()),
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      reason: map['reason']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}

/// Ringkasan kalkulasi shift (dipakai di dialog tutup shift & tampilan aktif shift)
@immutable
class ShiftSummary {
  /// Total pendapatan tunai saja (Payment dengan method=CASH dan status=PAID)
  final double totalCashRevenue;

  /// Total nominal non-tunai (QRIS, dsb) — hanya informasi, tidak masuk laci
  final double totalNonCashRevenue;

  /// Total kas masuk (CashMovement type=CASH_IN)
  final double totalCashIn;

  /// Total kas keluar (CashMovement type=CASH_OUT)
  final double totalCashOut;

  /// Modal kas awal saat shift dibuka
  final double openingCash;

  /// Daftar mutasi kas dalam shift ini
  final List<CashMovementModel> movements;

  const ShiftSummary({
    required this.openingCash,
    this.totalCashRevenue = 0,
    this.totalNonCashRevenue = 0,
    this.totalCashIn = 0,
    this.totalCashOut = 0,
    this.movements = const [],
  });

  /// Expected Cash = Modal Awal + Total Penjualan Tunai + Kas Masuk - Kas Keluar
  double get expectedCash =>
      openingCash + totalCashRevenue + totalCashIn - totalCashOut;

  /// Total seluruh penjualan (tunai + non-tunai) sebagai info
  double get totalRevenue => totalCashRevenue + totalNonCashRevenue;

  static const ShiftSummary empty = ShiftSummary(openingCash: 0);

  ShiftSummary copyWith({
    double? openingCash,
    double? totalCashRevenue,
    double? totalNonCashRevenue,
    double? totalCashIn,
    double? totalCashOut,
    List<CashMovementModel>? movements,
  }) {
    return ShiftSummary(
      openingCash: openingCash ?? this.openingCash,
      totalCashRevenue: totalCashRevenue ?? this.totalCashRevenue,
      totalNonCashRevenue: totalNonCashRevenue ?? this.totalNonCashRevenue,
      totalCashIn: totalCashIn ?? this.totalCashIn,
      totalCashOut: totalCashOut ?? this.totalCashOut,
      movements: movements ?? this.movements,
    );
  }
}
