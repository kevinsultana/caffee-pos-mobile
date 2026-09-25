import 'package:flutter/foundation.dart';
import '../core/utils/date_parser.dart';
import '../core/utils/phone_utils.dart';

@immutable
class CustomerModel {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  String? get normalizedPhone => normalizePhone(phone);

  String get displaySubtitle {
    final parts = <String>[];
    if (phone != null && phone!.isNotEmpty) parts.add(phone!);
    if (email != null && email!.isNotEmpty) parts.add(email!);
    return parts.join(' • ');
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      createdAt: tryParseDateTime(map['createdAt']),
      updatedAt: tryParseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? Function()? phone,
    String? Function()? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      phone: phone != null ? phone() : this.phone,
      email: email != null ? email() : this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
