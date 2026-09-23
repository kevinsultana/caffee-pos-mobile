import 'dart:async';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _savedUserKey = 'schaw_saved_user_id';

  @override
  AuthState build() {
    _loadSavedSession();
    return const AuthState(isLoading: true);
  }

  /// Memuat sesi user tersimpan dari penyimpanan lokal (Auto-login)
  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_savedUserKey);

      if (savedUserId != null && savedUserId.isNotEmpty) {
        final supaClient = supa.Supabase.instance.client;
        final userRecord = await supaClient
            .from('User')
            .select('id, storeId, roleId, username, email, name, status, Role(name), Store(id, name, code)')
            .eq('id', savedUserId)
            .maybeSingle();

        if (userRecord != null) {
          final status = userRecord['status']?.toString() ?? 'ACTIVE';
          if (status == 'ACTIVE') {
            final profile = UserProfile.fromMap(userRecord, authUserId: userRecord['id']);
            state = state.copyWith(
              profile: () => profile,
              isLoading: false,
              errorMessage: () => null,
            );
            return;
          }
        }
        // Jika user sudah tidak aktif, hapus dari local storage
        await prefs.remove(_savedUserKey);
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
    }
    state = const AuthState(isLoading: false);
  }

  /// Login resmi kasir (Sesuai dengan database web app menggunakan Username/Email & BCrypt)
  Future<String?> signInWithUsernameOrEmail(String usernameOrEmail, String password) async {
    final cleanInput = usernameOrEmail.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return 'Username dan kata sandi wajib diisi.';
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = supa.Supabase.instance.client;

      // 1. Cari data user di tabel public."User" berdasarkan username atau email
      final query = cleanInput.contains('@')
          ? supaClient
              .from('User')
              .select('id, storeId, roleId, username, email, name, status, passwordHash, Role(name), Store(id, name, code)')
              .ilike('email', cleanInput)
          : supaClient
              .from('User')
              .select('id, storeId, roleId, username, email, name, status, passwordHash, Role(name), Store(id, name, code)')
              .ilike('username', cleanInput);

      final userRecord = await query.maybeSingle();

      if (userRecord == null) {
        state = state.copyWith(isLoading: false);
        return 'Username atau kata sandi salah.';
      }

      // 2. Validasi status akun (RESIGNED / INACTIVE)
      final status = userRecord['status']?.toString() ?? 'ACTIVE';
      if (status == 'RESIGNED') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => 'Akun kasir telah RESIGNED dan tidak dapat mengakses sistem.',
        );
        return 'Akun kasir telah RESIGNED dan tidak dapat mengakses sistem.';
      }

      if (status == 'INACTIVE') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => 'Akun kasir sedang DINONAKTIFKAN. Silakan hubungi Owner.',
        );
        return 'Akun kasir sedang DINONAKTIFKAN. Silakan hubungi Owner.';
      }

      // 3. Verifikasi Kata Sandi dengan BCrypt (sesuai passwordHash dari web app)
      final passwordHash = userRecord['passwordHash']?.toString() ?? '';
      if (passwordHash.isEmpty) {
        state = state.copyWith(isLoading: false);
        return 'Akun belum memiliki kata sandi yang valid.';
      }

      bool isPasswordValid = false;
      try {
        isPasswordValid = BCrypt.checkpw(cleanPassword, passwordHash);
      } catch (e) {
        debugPrint('BCrypt error: $e');
      }

      if (!isPasswordValid) {
        state = state.copyWith(isLoading: false);
        return 'Username atau kata sandi salah.';
      }

      // 4. Simpan ID sesi ke local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedUserKey, userRecord['id'].toString());
      } catch (_) {}

      // 5. Update state dengan UserProfile
      final profile = UserProfile.fromMap(userRecord, authUserId: userRecord['id']);
      state = state.copyWith(
        profile: () => profile,
        isLoading: false,
        errorMessage: () => null,
      );

      return null;
    } catch (e) {
      final err = 'Terjadi kesalahan saat masuk: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: () => err);
      return err;
    }
  }

  /// Alias untuk kompatibilitas ke belakang
  Future<String?> signInWithEmailPassword(String usernameOrEmail, String password) =>
      signInWithUsernameOrEmail(usernameOrEmail, password);

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
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_savedUserKey, response['id'].toString());
        } catch (_) {}

        final profile = UserProfile.fromMap(response, authUserId: response['id']);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedUserKey);
    } catch (_) {}

    try {
      await supa.Supabase.instance.client.auth.signOut();
    } catch (_) {}

    state = const AuthState(isLoading: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
