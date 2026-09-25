import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  // Profil Form
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  bool _isSavingProfile = false;

  // Keamanan Form
  final _securityFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSavingPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();

    setState(() => _isSavingProfile = true);

    final error = await ref.read(authProvider.notifier).updateProfile(
          name: name,
          username: username,
        );

    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    if (error != null) {
      AppToast.showError(context, error);
    } else {
      AppToast.showSuccess(context, 'Data profil berhasil diperbarui!');
    }
  }

  Future<void> _handleSavePassword() async {
    if (!_securityFormKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      AppToast.showError(context, 'Konfirmasi kata sandi tidak cocok.');
      return;
    }

    if (currentPass == newPass) {
      AppToast.showWarning(context, 'Kata sandi baru tidak boleh sama dengan kata sandi lama.');
      return;
    }

    setState(() => _isSavingPassword = true);

    final error = await ref.read(authProvider.notifier).changePassword(
          currentPassword: currentPass,
          newPassword: newPass,
        );

    if (!mounted) return;
    setState(() => _isSavingPassword = false);

    if (error != null) {
      AppToast.showError(context, error);
    } else {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      AppToast.showSuccess(context, 'Kata sandi berhasil diubah!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Akun',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── HEADER INFO CARD ────────────────────────
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            (profile?.name.isNotEmpty == true
                                    ? profile!.name[0]
                                    : (profile?.username.isNotEmpty == true ? profile!.username[0] : 'K'))
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.name ?? 'Kasir',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${profile?.username ?? "user"} • ${profile?.email ?? ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      profile?.roleName ?? 'CASHIER',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      profile?.storeName ?? 'Schaw Cafe',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── CARD 1: INFORMASI PROFIL ─────────────────
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _profileFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Informasi Profil',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Nama Lengkap
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              hintText: 'Nama lengkap Anda',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nama lengkap wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Username
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                              hintText: 'username',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Username wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSavingProfile ? null : _handleSaveProfile,
                              icon: _isSavingProfile
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: const Text(
                                'Simpan Perubahan Profil',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── CARD 2: KEAMANAN & GANTI PASSWORD ─────────
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _securityFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.roseLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock_rounded, color: AppColors.rose, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Keamanan Akun',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ubah kata sandi akun kasir Anda secara berkala demi menjaga keamanan data toko.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 18),

                          // Password Lama
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrent,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi Saat Ini',
                              prefixIcon: const Icon(Icons.key_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Kata sandi saat ini wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password Baru
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi Baru (Min. 6 Karakter)',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Kata sandi baru wajib diisi.';
                              }
                              if (val.trim().length < 6) {
                                return 'Kata sandi minimal 6 karakter.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Konfirmasi Password Baru
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSavePassword(),
                            decoration: InputDecoration(
                              labelText: 'Konfirmasi Kata Sandi Baru',
                              prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Konfirmasi kata sandi wajib diisi.';
                              }
                              if (val.trim() != _newPasswordController.text.trim()) {
                                return 'Konfirmasi tidak sesuai dengan kata sandi baru.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.rose,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSavingPassword ? null : _handleSavePassword,
                              icon: _isSavingPassword
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.security_rounded, size: 18),
                              label: const Text(
                                'Perbarui Kata Sandi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
