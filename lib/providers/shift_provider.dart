import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/shift_model.dart';
import 'auth_provider.dart';

@immutable
class ShiftState {
  final ShiftModel? activeShift;
  final bool isLoading;
  final String? errorMessage;

  const ShiftState({
    this.activeShift,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasActiveShift => activeShift != null;

  ShiftState copyWith({
    ShiftModel? Function()? activeShift,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return ShiftState(
      activeShift: activeShift != null ? activeShift() : this.activeShift,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() {
    // Dengarkan perubahan user login untuk otomatis cek shift kasir
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.dbUserId != previous?.dbUserId) {
        checkActiveShift();
      } else if (!next.isAuthenticated) {
        state = const ShiftState();
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      Future.microtask(() => checkActiveShift());
    }

    return const ShiftState(isLoading: false);
  }

  /// Cek apakah kasir yang sedang login memiliki shift berstatus 'OPEN' di database
  Future<void> checkActiveShift() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.dbUserId.isEmpty) {
      state = const ShiftState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;

      // Query tabel public."Shift" dengan case-sensitive 'Shift'
      final response = await supaClient
          .from('Shift')
          .select('id, storeId, userId, status, openingCash, expectedCash, actualCash, difference, depositedCash, openedAt, closedAt, User:User(id, name, username)')
          .eq('userId', auth.dbUserId)
          .eq('status', 'OPEN')
          .order('openedAt', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final shift = ShiftModel.fromMap(response);
        state = state.copyWith(
          activeShift: () => shift,
          isLoading: false,
          errorMessage: () => null,
        );
      } else {
        state = state.copyWith(
          activeShift: () => null,
          isLoading: false,
          errorMessage: () => null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat status shift: ${e.toString()}',
      );
    }
  }

  /// Buka shift baru untuk kasir yang sedang login
  Future<String?> openShift({required double openingCash}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.dbUserId.isEmpty) {
      return 'Sesi kasir tidak valid. Silakan login kembali.';
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;

      // Cek apakah toko memiliki batasan shift aktif
      final storeId = auth.storeId;
      if (storeId.isNotEmpty) {
        final activeStoreShifts = await supaClient
            .from('Shift')
            .select('id')
            .eq('storeId', storeId)
            .eq('status', 'OPEN');

        final storeSettings = await supaClient
            .from('StoreSettings')
            .select('maxActiveShifts')
            .eq('storeId', storeId)
            .maybeSingle();

        final maxActiveShifts = (storeSettings?['maxActiveShifts'] as num?)?.toInt() ?? 1;

        if (activeStoreShifts.length >= maxActiveShifts) {
          state = state.copyWith(isLoading: false);
          return 'Batas shift aktif toko ($maxActiveShifts shift) telah tercapai. Tutup shift kasir lain terlebih dahulu.';
        }
      }

      final insertData = {
        'storeId': storeId.isNotEmpty ? storeId : null,
        'userId': auth.dbUserId,
        'status': 'OPEN',
        'openingCash': openingCash,
        'openedAt': DateTime.now().toIso8601String(),
      };

      final response = await supaClient
          .from('Shift')
          .insert(insertData)
          .select('id, storeId, userId, status, openingCash, expectedCash, actualCash, difference, depositedCash, openedAt, closedAt, User:User(id, name, username)')
          .single();

      final newShift = ShiftModel.fromMap(response);
      state = state.copyWith(
        activeShift: () => newShift,
        isLoading: false,
        errorMessage: () => null,
      );
      return null;
    } catch (e) {
      final err = 'Gagal membuka shift: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: () => err);
      return err;
    }
  }

  /// Tutup shift kasir yang sedang aktif
  Future<String?> closeShift({
    required double actualCash,
    double depositedCash = 0,
  }) async {
    final current = state.activeShift;
    if (current == null) {
      return 'Tidak ada shift aktif yang ditemukan.';
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final diff = actualCash - current.openingCash;

      await supaClient
          .from('Shift')
          .update({
            'status': 'CLOSED',
            'closedAt': DateTime.now().toIso8601String(),
            'actualCash': actualCash,
            'expectedCash': current.openingCash, // Akan disempurnakan di tahap POS cash
            'difference': diff,
            'depositedCash': depositedCash,
          })
          .eq('id', current.id);

      state = state.copyWith(
        activeShift: () => null,
        isLoading: false,
        errorMessage: () => null,
      );
      return null;
    } catch (e) {
      final err = 'Gagal menutup shift: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: () => err);
      return err;
    }
  }
}

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
