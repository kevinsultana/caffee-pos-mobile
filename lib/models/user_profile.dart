import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String dbUserId; // UUID dari tabel public."User" (Foreign Key utama)
  final String? authUserId; // UUID dari auth.users Supabase
  final String storeId;
  final String? roleId;
  final String username;
  final String email;
  final String name;
  final String status; // ACTIVE, INACTIVE, RESIGNED
  final String roleName; // OWNER, MANAGER, CASHIER, dll
  final String storeName;
  final String storeCode;

  const UserProfile({
    required this.dbUserId,
    this.authUserId,
    required this.storeId,
    this.roleId,
    required this.username,
    required this.email,
    required this.name,
    this.status = 'ACTIVE',
    this.roleName = 'CASHIER',
    this.storeName = 'Schaw Cafe',
    this.storeCode = 'MAIN',
  });

  bool get isActive => status == 'ACTIVE';
  bool get isOwner => roleName == 'OWNER';
  bool get isManager => roleName == 'MANAGER';
  bool get isCashier => roleName == 'CASHIER';

  factory UserProfile.fromMap(Map<String, dynamic> map, {String? authUserId}) {
    // Role object handling (join relation Role(name) / role(name))
    final roleData = map['Role'] ?? map['role'];
    String roleName = 'CASHIER';
    if (roleData is Map<String, dynamic> && roleData['name'] != null) {
      roleName = roleData['name'].toString();
    } else if (map['roleName'] != null) {
      roleName = map['roleName'].toString();
    }

    // Store object handling (join relation Store(id, name, code) / store)
    final storeData = map['Store'] ?? map['store'];
    String storeName = 'Schaw Cafe';
    String storeCode = 'MAIN';
    if (storeData is Map<String, dynamic>) {
      storeName = storeData['name']?.toString() ?? 'Schaw Cafe';
      storeCode = storeData['code']?.toString() ?? 'MAIN';
    }

    return UserProfile(
      dbUserId: map['id']?.toString() ?? '',
      authUserId: authUserId,
      storeId: map['storeId']?.toString() ?? '',
      roleId: map['roleId']?.toString(),
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? (map['username']?.toString() ?? 'Kasir'),
      status: map['status']?.toString() ?? 'ACTIVE',
      roleName: roleName,
      storeName: storeName,
      storeCode: storeCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': dbUserId,
      'authUserId': authUserId,
      'storeId': storeId,
      'roleId': roleId,
      'username': username,
      'email': email,
      'name': name,
      'status': status,
      'roleName': roleName,
      'storeName': storeName,
      'storeCode': storeCode,
    };
  }
}
