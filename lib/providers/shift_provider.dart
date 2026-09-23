import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/shift_model.dart';
import 'auth_provider.dart';

@immutable
class ShiftState {
  final ShiftModel? activeShift; // Shift aktif milik user yang sedang login
  final List<ActiveStoreShiftInfo> otherActiveShifts; // Shift kasir lain yang sedang OPEN di toko
  final int maxActiveShifts; // Batas maksimal shift aktif toko dari StoreSettings (default 1)
  final bool isLoading;
  final String? errorMessage;

  const ShiftState({
    this.activeShift,
    this.otherActiveShifts = const [],
    this.maxActiveShifts = 1,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Apakah user yang sedang login memiliki shift aktif
  bool get hasActiveShift => activeShift != null;

  /// Total shift berstatus 'OPEN' di toko (termasuk milik user ini)
  int get totalStoreOpenShifts => (hasActiveShift ? 1 : 0) + otherActiveShifts.length;

  /// Apakah limit maksimal shift aktif di toko sudah terpenuhi
  bool get isLimitReached => totalStoreOpenShifts >= maxActiveShifts;

  /// Apakah user saat ini berhak membuka shift baru:
  /// Syarat: Belum punya shift aktif DAN limit shift toko belum tercapai
  bool get canOpenNewShift => !hasActiveShift && !isLimitReached;

  /// Apakah akses kasir / shift user ini terhalang oleh shift kasir lain yang sedang aktif dan kuota toko penuh
  bool get isBlockedByOtherShift => !hasActiveShift && otherActiveShifts.isNotEmpty && isLimitReached;

  ShiftState copyWith({
    ShiftModel? Function()? activeShift,
    List<ActiveStoreShiftInfo>? otherActiveShifts,
    int? maxActiveShifts,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return ShiftState(
      activeShift: activeShift != null ? activeShift() : this.activeShift,
      otherActiveShifts: otherActiveShifts ?? this.otherActiveShifts,
      maxActiveShifts: maxActiveShifts ?? this.maxActiveShifts,
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

  /// Cek status shift kasir yang login, kuota maxActiveShifts toko, dan shift kasir lain
  Future<void> checkActiveShift() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.dbUserId.isEmpty) {
      state = const ShiftState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final storeId = auth.storeId;

      // 1. Cek shift aktif milik user yang sedang login
      final userShiftResp = await supaClient
          .from('Shift')
          .select('id, storeId, userId, status, openingCash, expectedCash, actualCash, difference, depositedCash, openedAt, closedAt, User:User(id, name, username)')
          .eq('userId', auth.dbUserId)
          .eq('status', 'OPEN')
          .order('openedAt', ascending: false)
          .limit(1)
          .maybeSingle();

      final currentShift = userShiftResp != null ? ShiftModel.fromMap(userShiftResp) : null;

      // 2. Ambil pengaturan batas shift toko (maxActiveShifts)
      int maxActiveShifts = 1;
      if (storeId.isNotEmpty) {
        final storeSettingsResp = await supaClient
            .from('StoreSettings')
            .select('maxActiveShifts')
            .eq('storeId', storeId)
            .maybeSingle();

        if (storeSettingsResp != null && storeSettingsResp['maxActiveShifts'] != null) {
          maxActiveShifts = (storeSettingsResp['maxActiveShifts'] as num).toInt();
        }
      }

      // 3. Cek shift aktif milik kasir lain yang sedang berjalan di toko
      var otherShiftsQuery = supaClient
          .from('Shift')
          .select('id, storeId, userId, status, openingCash, openedAt, User:User(id, name, username)')
          .eq('status', 'OPEN')
          .neq('userId', auth.dbUserId);

      if (storeId.isNotEmpty) {
        otherShiftsQuery = otherShiftsQuery.eq('storeId', storeId);
      }

      final otherShiftsResp = await otherShiftsQuery.order('openedAt', ascending: false);
      final List<ActiveStoreShiftInfo> otherShifts = (otherShiftsResp as List)
          .map((s) => ActiveStoreShiftInfo.fromMap(s as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        activeShift: () => currentShift,
        otherActiveShifts: otherShifts,
        maxActiveShifts: maxActiveShifts,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat status shift: ${e.toString()}',
      );
    }
  }

  /// Buka shift baru untuk kasir yang sedang login (dengan validasi limit StoreSettings)
  Future<String?> openShift({required double openingCash}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.dbUserId.isEmpty) {
      return 'Sesi kasir tidak valid. Silakan login kembali.';
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final storeId = auth.storeId;

      // 1. Cek apakah user yang login ini masih memiliki shift OPEN
      if (state.hasActiveShift) {
        state = state.copyWith(isLoading: false);
        return 'Anda masih memiliki shift yang sedang aktif. Silakan tutup terlebih dahulu.';
      }

      // 2. Cek limit toko dari StoreSettings
      if (storeId.isNotEmpty) {
        final storeSettingsResp = await supaClient
            .from('StoreSettings')
            .select('maxActiveShifts')
            .eq('storeId', storeId)
            .maybeSingle();

        final maxActiveShifts = (storeSettingsResp?['maxActiveShifts'] as num?)?.toInt() ?? 1;

        final activeStoreShifts = await supaClient
            .from('Shift')
            .select('id, userId, User:User(name, username)')
            .eq('storeId', storeId)
            .eq('status', 'OPEN');

        if (activeStoreShifts.length >= maxActiveShifts) {
          state = state.copyWith(isLoading: false);
          final otherUser = activeStoreShifts.first['User'];
          final otherName = otherUser != null
              ? (otherUser['name']?.toString() ?? otherUser['username']?.toString() ?? 'Kasir Lain')
              : 'Kasir Lain';

          return 'Batas shift aktif toko ($maxActiveShifts shift) telah tercapai. Shift sedang berjalan oleh $otherName. Tutup shift tersebut terlebih dahulu atau ubah batas shift di pengaturan toko.';
        }
      }

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final insertData = {
        'storeId': storeId.isNotEmpty ? storeId : null,
        'userId': auth.dbUserId,
        'status': 'OPEN',
        'openingCash': openingCash,
        'openedAt': nowUtc,
        'updatedAt': nowUtc,
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

      // Refresh seluruh data shift toko
      await checkActiveShift();
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
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final diff = actualCash - current.openingCash;

      await supaClient
          .from('Shift')
          .update({
            'status': 'CLOSED',
            'closedAt': nowUtc,
            'updatedAt': nowUtc,
            'actualCash': actualCash,
            'expectedCash': current.openingCash,
            'difference': diff,
            'depositedCash': depositedCash,
          })
          .eq('id', current.id);

      state = state.copyWith(
        activeShift: () => null,
        isLoading: false,
        errorMessage: () => null,
      );

      // Refresh status shift toko
      await checkActiveShift();
      return null;
    } catch (e) {
      final err = 'Gagal menutup shift: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: () => err);
      return err;
    }
  }
}

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
