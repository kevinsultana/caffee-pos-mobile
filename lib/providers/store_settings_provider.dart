import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../core/utils/uuid_generator.dart';
import '../models/store_settings_model.dart';
import 'auth_provider.dart';

@immutable
class StoreSettingsState {
  final StoreSettingsModel settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const StoreSettingsState({
    required this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  StoreSettingsState copyWith({
    StoreSettingsModel? settings,
    bool? isLoading,
    bool? isSaving,
    String? Function()? errorMessage,
  }) {
    return StoreSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class StoreSettingsNotifier extends Notifier<StoreSettingsState> {
  @override
  StoreSettingsState build() {
    // Dengarkan perubahan login untuk otomatis memuat pengaturan toko
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.storeId != previous?.storeId) {
        fetchSettings(next.storeId);
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.storeId.isNotEmpty) {
      Future.microtask(() => fetchSettings(authState.storeId));
    }

    return StoreSettingsState(
      settings: StoreSettingsModel.defaultSettings(authState.storeId),
      isLoading: authState.isAuthenticated,
    );
  }

  /// Ambil data pengaturan toko dan format struk dari Supabase
  Future<void> fetchSettings(String storeId) async {
    if (storeId.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final response = await supaClient
          .from('StoreSettings')
          .select()
          .eq('storeId', storeId)
          .maybeSingle();

      if (response != null) {
        final settings = StoreSettingsModel.fromMap(response);
        state = state.copyWith(
          settings: settings,
          isLoading: false,
          errorMessage: () => null,
        );
      } else {
        // Belum ada data di database, gunakan default
        state = state.copyWith(
          settings: StoreSettingsModel.defaultSettings(storeId),
          isLoading: false,
          errorMessage: () => null,
        );
      }
    } catch (e) {
      debugPrint('[StoreSettingsNotifier] fetchSettings error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat pengaturan toko: ${e.toString()}',
      );
    }
  }

  /// Simpan perubahan pengaturan toko dan struk ke Supabase
  Future<String?> updateSettings(StoreSettingsModel updated) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final data = updated.toMap();
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Pastikan ada UUID jika data baru
      if (data['id'] == null || data['id'].toString().isEmpty) {
        data['id'] = UuidGenerator.v4();
        data['createdAt'] = nowUtc;
      }
      data['updatedAt'] = nowUtc;

      final res = await supaClient
          .from('StoreSettings')
          .upsert(data, onConflict: 'storeId')
          .select()
          .single();

      final savedModel = StoreSettingsModel.fromMap(res);
      state = state.copyWith(
        settings: savedModel,
        isSaving: false,
        errorMessage: () => null,
      );

      return null;
    } catch (e) {
      debugPrint('[StoreSettingsNotifier] updateSettings error: $e');
      final err = 'Gagal menyimpan pengaturan: ${e.toString()}';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => err,
      );
      return err;
    }
  }
}

final storeSettingsProvider =
    NotifierProvider<StoreSettingsNotifier, StoreSettingsState>(
  StoreSettingsNotifier.new,
);
