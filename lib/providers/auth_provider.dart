import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/user_profile.dart';

@immutable
class AuthState {
  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => profile != null;
  String get userEmail => profile?.email ?? '';
  String get userName => profile?.name ?? 'Kasir';
  String get roleName => profile?.roleName ?? 'KASIR';
  String get dbUserId => profile?.dbUserId ?? '';
  String get storeId => profile?.storeId ?? '';
  String get storeName => profile?.storeName ?? 'Schaw Cafe';

  AuthState copyWith({
    UserProfile? Function()? profile,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return AuthState(
      profile: profile != null ? profile() : this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<supa.AuthState>? _authSubscription;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _initSupabaseAuthListener();
    return const AuthState(isLoading: true);
  }

  void _initSupabaseAuthListener() {
    try {
      final supaClient = supa.Supabase.instance.client;

      // Cek sesi yang sudah tersimpan di lokal (auto-login)
      final session = supaClient.auth.currentSession;
      if (session != null && session.user.email != null) {
        _syncUserProfile(session.user.email!, authUserId: session.user.id);
      } else {
        state = const AuthState(isLoading: false);
      }

      // Dengarkan perubahan sesi autentikasi Supabase
      _authSubscription = supaClient.auth.onAuthStateChange.listen((data) {
        final currentSession = data.session;
        if (currentSession != null && currentSession.user.email != null) {
          _syncUserProfile(currentSession.user.email!, authUserId: currentSession.user.id);
        } else {
          state = const AuthState(isLoading: false);
        }
      });
    } catch (e) {
      state = const AuthState(isLoading: false);
    }
  }

  /// Sinkronisasi email auth Supabase dengan tabel public."User" di database utama
  Future<void> _syncUserProfile(String email, {String? authUserId}) async {
    try {
      final supaClient = supa.Supabase.instance.client;
      final cleanEmail = email.trim().toLowerCase();

      // 1. Cari berdasarkan email
      var response = await supaClient
          .from('User')
          .select('id, storeId, roleId, username, email, name, status, Role(name), Store(id, name, code)')
          .eq('email', cleanEmail)
          .maybeSingle();

      // 2. Jika tidak ditemukan via email, coba cari via username
      if (response == null) {
        final usernamePrefix = cleanEmail.split('@').first;
        response = await supaClient
            .from('User')
            .select('id, storeId, roleId, username, email, name, status, Role(name), Store(id, name, code)')
            .eq('username', usernamePrefix)
            .maybeSingle();
      }

      if (response != null) {
        final status = response['status']?.toString() ?? 'ACTIVE';

        // Validasi status user: Cegah user INACTIVE atau RESIGNED
        if (status == 'RESIGNED') {
          await supaClient.auth.signOut();
          state = state.copyWith(
            profile: () => null,
            isLoading: false,
            errorMessage: () => 'Akun kasir telah RESIGNED dan tidak dapat mengakses sistem.',
          );
          return;
        }

        if (status == 'INACTIVE') {
          await supaClient.auth.signOut();
          state = state.copyWith(
            profile: () => null,
            isLoading: false,
            errorMessage: () => 'Akun kasir sedang DINONAKTIFKAN. Silakan hubungi Owner.',
          );
          return;
        }

        final profile = UserProfile.fromMap(response, authUserId: authUserId);
        state = state.copyWith(
          profile: () => profile,
          isLoading: false,
          errorMessage: () => null,
        );
      } else {
        // User terotentikasi di Supabase Auth tapi belum terdaftar di tabel User toko
        final fallbackProfile = UserProfile(
          dbUserId: authUserId ?? 'unknown-user',
          authUserId: authUserId,
          storeId: '',
          username: cleanEmail.split('@').first,
          email: cleanEmail,
          name: cleanEmail.split('@').first,
          status: 'ACTIVE',
          roleName: 'CASHIER',
        );
        state = state.copyWith(
          profile: () => fallbackProfile,
          isLoading: false,
          errorMessage: () => null,
        );
      }
    } catch (e) {
      // Jika terjadi kendala jaringan/koneksi
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal menyinkronkan profil kasir: ${e.toString()}',
      );
    }
  }

  /// Login resmi kasir via Supabase Auth
  Future<String?> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return 'Email dan kata sandi wajib diisi.';
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final res = await supa.Supabase.instance.client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      if (res.user != null) {
        await _syncUserProfile(res.user!.email ?? cleanEmail, authUserId: res.user!.id);
        if (state.errorMessage != null) {
          return state.errorMessage;
        }
        return null;
      }
      state = state.copyWith(isLoading: false);
      return 'Gagal melakukan otentikasi. Silakan periksa kredensial Anda.';
    } on supa.AuthException catch (e) {
      String userMessage = e.message;
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        userMessage = 'Email atau kata sandi kasir salah.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        userMessage = 'Email kasir belum dikonfirmasi di Supabase.';
      }
      state = state.copyWith(isLoading: false, errorMessage: () => userMessage);
      return userMessage;
    } catch (e) {
      final err = 'Terjadi kesalahan: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: () => err);
      return err;
    }
  }

  /// Login instan mode Demo (mengambil akun kasir aktif pertama dari database jika tersedia)
  Future<void> loginDemo([String username = 'owner']) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = supa.Supabase.instance.client;
      final response = await supaClient
          .from('User')
          .select('id, storeId, roleId, username, email, name, status, Role(name), Store(id, name, code)')
          .eq('status', 'ACTIVE')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final profile = UserProfile.fromMap(response, authUserId: 'demo-auth-id');
        state = state.copyWith(
          profile: () => profile,
          isLoading: false,
          errorMessage: () => null,
        );
        return;
      }
    } catch (_) {
      // Abaikan jika query demo gagal, gunakan data fallback
    }

    // Fallback akun dummy jika database belum memiliki user
    final fallbackProfile = UserProfile(
      dbUserId: 'demo-user-1234',
      authUserId: 'demo-auth-id',
      storeId: 'demo-store-1234',
      username: username,
      email: '$username@schawcafe.com',
      name: 'Kasir Demo ($username)',
      roleName: 'CASHIER',
      storeName: 'Schaw Cafe Demo',
    );

    state = state.copyWith(
      profile: () => fallbackProfile,
      isLoading: false,
      errorMessage: () => null,
    );
  }

  /// Sign out dari sesi aktif
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    try {
      await supa.Supabase.instance.client.auth.signOut();
    } catch (_) {}

    state = const AuthState(isLoading: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
