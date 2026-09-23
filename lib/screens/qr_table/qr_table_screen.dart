import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';

/// URL tetap menu QR publik — langsung diarahkan ke halaman menu
const _kMenuUrl = 'https://caffee-pos.vercel.app/menu';

class QrTableScreen extends ConsumerStatefulWidget {
  const QrTableScreen({super.key});

  @override
  ConsumerState<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends ConsumerState<QrTableScreen> {
  final GlobalKey _qrCardKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);

    try {
      // Delay singkat untuk memastikan RepaintBoundary ter-render sempurna
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary =
          _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Gagal mendeteksi tampilan kartu QR.');
      }

      // Capture dengan pixelRatio 3.0 untuk ketajaman tinggi (high-res PNG)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception('Gagal mengonversi gambar ke format PNG.');
      }

      // Simpan ke galeri menggunakan package Gal (MediaStore API modern)
      await Gal.putImageBytes(pngBytes, name: 'QR_Menu_Cafe');

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppToast.showSuccess(
        context,
        'QR Code Menu berhasil disimpan ke Galeri!',
        duration: const Duration(seconds: 3),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      String errorMessage = 'Gagal menyimpan gambar ke galeri.';
      if (e.type == GalExceptionType.accessDenied) {
        errorMessage =
            'Izin akses galeri ditolak. Harap izinkan akses penyimpanan di Pengaturan Aplikasi.';
      } else if (e.type == GalExceptionType.notEnoughSpace) {
        errorMessage = 'Ruang penyimpanan perangkat tidak mencukupi.';
      }

      AppToast.showError(context, errorMessage, duration: const Duration(seconds: 4));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showError(context, 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final printerState = ref.watch(printerProvider);
    final storeName =
        authState.storeName.isNotEmpty ? authState.storeName : 'SCHAW CAFE';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Kartu QR (dibungkus RepaintBoundary untuk capture ke galeri)
                Center(
                  child: RepaintBoundary(
                    key: _qrCardKey,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Cafe
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primaryLight),
                            ),
                            child: const Icon(
                              Icons.coffee_rounded,
                              size: 26,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            storeName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Scan QR untuk Pesan & Bayar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // QR Code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1.5,
                              ),
                            ),
                            child: QrImageView(
                              data: _kMenuUrl,
                              version: QrVersions.auto,
                              size: 200,
                              gapless: true,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size(36, 36),
                              ),
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF0F172A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Footer Kartu
                          const Text(
                            'Buka kamera ponsel Anda & arahkan ke QR Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tombol Simpan ke Galeri
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveQrToGallery,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _isSaving
                          ? 'Menyimpan ke Galeri...'
                          : 'Simpan ke Galeri Perangkat',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tombol Cetak via Printer Bluetooth
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (!printerState.isConnected) {
                      AppToast.showWarning(
                        context,
                        'Printer thermal belum terhubung. Buka Pengaturan Printer untuk menyambungkan.',
                      );
                      return;
                    }
                    AppToast.showInfo(
                      context,
                      'Mengirim data Tent Card ke printer thermal...',
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(
                    Icons.print_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Cetak Tent Card ke Printer Bluetooth',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info URL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: AppColors.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _kMenuUrl,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
