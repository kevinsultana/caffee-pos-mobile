import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      AppToast.showError(context, 'Konfirmasi kata sandi tidak cocok.');
      return;
    }

    if (currentPass == newPass) {
      AppToast.showWarning(context, 'Kata sandi baru tidak boleh sama dengan kata sandi saat ini.');
      return;
    }

    setState(() => _isLoading = true);

    final error = await ref.read(authProvider.notifier).changePassword(
          currentPassword: currentPass,
          newPassword: newPass,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      AppToast.showError(context, error);
    } else {
      AppToast.showSuccess(
        context,
        'Kata sandi berhasil diperbarui! Selamat bertugas.',
        duration: const Duration(seconds: 3),
      );
      // GoRouter redirect will automatically route to /pos since mustChangePassword is false
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Wajib Ganti Kata Sandi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Keluar Akun',
            icon: const Icon(Icons.logout_rounded, color: AppColors.rose),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi Keluar'),
                  content: const Text('Apakah Anda ingin keluar dan membatalkan pergantian kata sandi?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icon & Header
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryLight, width: 2),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Perbarui Kata Sandi Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Halo ${user?.name ?? "Kasir"}, demi keamanan akun Anda, Anda wajib mengganti kata sandi sebelum dapat mengakses sistem kasir.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Alert Info Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.security_rounded, size: 20, color: AppColors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Gunakan minimal 6 karakter kombinasi huruf dan angka yang aman.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Field 1: Kata Sandi Saat Ini
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
                        const SizedBox(height: 16),

                        // Field 2: Kata Sandi Baru
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
                        const SizedBox(height: 16),

                        // Field 3: Konfirmasi Kata Sandi Baru
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSubmit(),
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
                        const SizedBox(height: 26),

                        // Submit Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleSubmit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Simpan Kata Sandi Baru',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
