import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/utils/date_parser.dart';

@immutable
class ShiftModel {
  final String id;
  final String storeId;
  final String userId;
  final String status; // 'OPEN' or 'CLOSED'
  final double openingCash;
  final double? expectedCash;
  final double? actualCash;
  final double? difference;
  final double? depositedCash;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? userName;

  const ShiftModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.status,
    required this.openingCash,
    this.expectedCash,
    this.actualCash,
    this.difference,
    this.depositedCash,
    required this.openedAt,
    this.closedAt,
    this.userName,
  });

  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';

  String get formattedOpeningCash {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(openingCash);
  }

  String get formattedOpenedAt {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(openedAt);
    } catch (_) {
      return DateFormat('dd MMM yyyy, HH:mm').format(openedAt);
    }
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    // Parse nested user if joined
    String? userName;
    final userData = map['User'] ?? map['user'];
    if (userData is Map<String, dynamic>) {
      userName = userData['name']?.toString() ?? userData['username']?.toString();
    }

    return ShiftModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'OPEN',
      openingCash: (map['openingCash'] is num)
          ? (map['openingCash'] as num).toDouble()
          : double.tryParse(map['openingCash']?.toString() ?? '0') ?? 0.0,
      expectedCash: map['expectedCash'] != null
          ? ((map['expectedCash'] as num?)?.toDouble() ??
              double.tryParse(map['expectedCash'].toString()))
          : null,
      actualCash: map['actualCash'] != null
          ? ((map['actualCash'] as num?)?.toDouble() ??
              double.tryParse(map['actualCash'].toString()))
          : null,
      difference: map['difference'] != null
          ? ((map['difference'] as num?)?.toDouble() ??
              double.tryParse(map['difference'].toString()))
          : null,
      depositedCash: map['depositedCash'] != null
          ? ((map['depositedCash'] as num?)?.toDouble() ??
              double.tryParse(map['depositedCash'].toString()))
          : null,
      openedAt: parseDateTime(map['openedAt']),
      closedAt: tryParseDateTime(map['closedAt']),
      userName: userName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'userId': userId,
      'status': status,
      'openingCash': openingCash,
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'difference': difference,
      'depositedCash': depositedCash,
      'openedAt': openedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }
}

@immutable
class ActiveStoreShiftInfo {
  final String id;
  final String userId;
  final String userName;
  final String username;
  final double openingCash;
  final DateTime openedAt;

  const ActiveStoreShiftInfo({
    required this.id,
    required this.userId,
    required this.userName,
    required this.username,
    required this.openingCash,
    required this.openedAt,
  });

  String get formattedOpenedAt {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(openedAt);
    } catch (_) {
      return DateFormat('dd MMM yyyy, HH:mm').format(openedAt);
    }
  }

  factory ActiveStoreShiftInfo.fromMap(Map<String, dynamic> map) {
    String userName = 'Kasir';
    String username = 'kasir';
    final userData = map['User'] ?? map['user'];
    if (userData is Map<String, dynamic>) {
      userName = userData['name']?.toString() ?? 'Kasir';
      username = userData['username']?.toString() ?? 'kasir';
    }

    return ActiveStoreShiftInfo(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: userName,
      username: username,
      openingCash: (map['openingCash'] is num)
          ? (map['openingCash'] as num).toDouble()
          : double.tryParse(map['openingCash']?.toString() ?? '0') ?? 0.0,
      openedAt: parseDateTime(map['openedAt']),
    );
  }
}
