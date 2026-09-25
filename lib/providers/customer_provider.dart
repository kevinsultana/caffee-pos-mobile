import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/utils/phone_utils.dart';
import '../core/utils/uuid_generator.dart';
import '../models/customer_model.dart';
import 'auth_provider.dart';

@immutable
class CustomerState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? errorMessage;

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CustomerState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class CustomerNotifier extends Notifier<CustomerState> {
  @override
  CustomerState build() {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && next.storeId != prev?.storeId) {
        fetchCustomers(next.storeId);
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.storeId.isNotEmpty) {
      Future.microtask(() => fetchCustomers(authState.storeId));
    }

    return const CustomerState();
  }

  /// Ambil daftar pelanggan/member toko dari tabel Customer di Supabase
  Future<void> fetchCustomers([String? explicitStoreId]) async {
    final storeId = explicitStoreId ?? ref.read(authProvider).storeId;
    if (storeId.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final response = await supaClient
          .from('Customer')
          .select()
          .eq('storeId', storeId)
          .order('name', ascending: true);

      final list = (response as List)
          .map((m) => CustomerModel.fromMap(m as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        customers: list,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      debugPrint('[CustomerNotifier] fetchCustomers error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat data pelanggan: ${e.toString()}',
      );
    }
  }

  /// Cari kecocokan member berdasarkan nomor HP (otomatis dinormalisasi 08xx / 62xx)
  Future<CustomerModel?> findCustomerByPhone(String rawPhone) async {
    final normPhone = normalizePhone(rawPhone);
    if (normPhone == null || normPhone.isEmpty) return null;

    // 1. Cek di daftar pelanggan lokal yang sudah dimuat
    for (final c in state.customers) {
      if (c.normalizedPhone == normPhone) {
        return c;
      }
    }

    // 2. Jika tidak ada di lokal, lakukan pencarian langsung ke database Supabase
    try {
      final storeId = ref.read(authProvider).storeId;
      if (storeId.isEmpty) return null;

      final supaClient = Supabase.instance.client;
      final response = await supaClient
          .from('Customer')
          .select()
          .eq('storeId', storeId)
          .or('phone.eq.$normPhone,phone.eq.$rawPhone')
          .maybeSingle();

      if (response != null) {
        final found = CustomerModel.fromMap(response);
        // Tambahkan ke cache lokal jika belum ada
        if (!state.customers.any((c) => c.id == found.id)) {
          state = state.copyWith(
            customers: [found, ...state.customers],
          );
        }
        return found;
      }
    } catch (e) {
      debugPrint('[CustomerNotifier] findCustomerByPhone error: $e');
    }

    return null;
  }

  /// Daftarkan pelanggan/member baru ke Supabase & perbarui state lokal
  Future<CustomerModel> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    final storeId = ref.read(authProvider).storeId;
    if (storeId.isEmpty) {
      throw Exception('Store ID tidak valid atau sesi login kedaluwarsa.');
    }

    final normPhone = normalizePhone(phone);
    final cleanEmail = (email?.trim().isNotEmpty == true) ? email!.trim() : null;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final newId = UuidGenerator.v4();

    final data = {
      'id': newId,
      'storeId': storeId,
      'name': name.trim(),
      'phone': normPhone,
      'email': cleanEmail,
      'createdAt': nowUtc,
      'updatedAt': nowUtc,
    };

    final supaClient = Supabase.instance.client;
    final res = await supaClient
        .from('Customer')
        .insert(data)
        .select()
        .single();

    final newCustomer = CustomerModel.fromMap(res);

    state = state.copyWith(
      customers: [
        newCustomer,
        ...state.customers.where((c) => c.id != newCustomer.id),
      ],
    );

    return newCustomer;
  }
}

final customerProvider =
    NotifierProvider<CustomerNotifier, CustomerState>(CustomerNotifier.new);
