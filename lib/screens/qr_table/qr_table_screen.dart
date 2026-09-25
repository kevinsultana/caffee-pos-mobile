import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';

/// URL tetap menu QR publik — langsung diarahkan ke halaman menu
const _kBaseMenuUrl = 'https://caffee-pos.vercel.app/menu';

class QrTableScreen extends ConsumerStatefulWidget {
  const QrTableScreen({super.key});

  @override
  ConsumerState<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends ConsumerState<QrTableScreen> {
  final GlobalKey _qrCardKey = GlobalKey();
  final TextEditingController _tableController = TextEditingController();
  bool _isSaving = false;
  bool _isPrinting = false;

  String get _currentUrl {
    final table = _tableController.text.trim();
    if (table.isEmpty || table.toLowerCase() == 'umum') {
      return _kBaseMenuUrl;
    }
    return '$_kBaseMenuUrl?table=${Uri.encodeComponent(table)}';
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);

    try {
      // Delay singkat untuk memastikan RepaintBoundary ter-render sempurna
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary =
          _qrCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
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

      final tableLabel = _tableController.text.trim().replaceAll(' ', '_');
      final fileName = tableLabel.isNotEmpty
          ? 'QR_Menu_$tableLabel'
          : 'QR_Menu_SchawCafe';

      // Simpan ke galeri menggunakan package Gal (MediaStore API modern)
      await Gal.putImageBytes(pngBytes, name: fileName);

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppToast.showSuccess(
        context,
        'Kartu QR Code Meja berhasil disimpan ke Galeri!',
        duration: const Duration(seconds: 3),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      String errorMessage = 'Gagal menyimpan gambar ke galeri.';
      if (e.type == GalExceptionType.accessDenied) {
        errorMessage = 'Izin akses galeri ditolak. Harap izinkan akses media di Pengaturan Aplikasi.';
      } else if (e.type == GalExceptionType.notEnoughSpace) {
        errorMessage = 'Ruang penyimpanan perangkat tidak mencukupi.';
      }

      AppToast.showError(
        context,
        errorMessage,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showError(context, 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> _handlePrintTentCard(String storeName) async {
    final printerState = ref.read(printerProvider);

    if (!printerState.isConnected) {
      AppToast.showWarning(
        context,
        'Printer thermal Bluetooth belum terhubung. Sambungkan printer terlebih dahulu.',
      );
      context.push('/settings/printer');
      return;
    }

    setState(() => _isPrinting = true);
    final table = _tableController.text.trim();

    try {
      final success = await ref
          .read(printerProvider.notifier)
          .printQrTentCard(
            qrUrl: _currentUrl,
            storeName: storeName,
            tableNumber: table.isNotEmpty ? table : null,
          );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (success) {
        AppToast.showSuccess(
          context,
          'Tent card meja berhasil dicetak ke printer!',
          duration: const Duration(seconds: 3),
        );
      } else {
        AppToast.showError(
          context,
          'Gagal mencetak ke printer. Periksa koneksi Bluetooth printer.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      AppToast.showError(context, 'Error mencetak: ${e.toString()}');
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    AppToast.showSuccess(
      context,
      'Tautan menu QR berhasil disalin ke clipboard!',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final printerState = ref.watch(printerProvider);
    final storeName = authState.storeName.isNotEmpty
        ? authState.storeName
        : 'SCHAW CAFE';
    final currentTable = _tableController.text.trim();

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
                // ── STATUS KONEKSI PRINTER BANNER ───────────
                InkWell(
                  onTap: () => context.push('/settings/printer'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: printerState.isConnected
                          ? AppColors.primaryContainer
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: printerState.isConnected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          printerState.isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded,
                          size: 20,
                          color: printerState.isConnected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            printerState.isConnected
                                ? 'Printer Terhubung: ${printerState.connectedDevice?.name ?? "Thermal Printer"}'
                                : 'Printer Belum Terhubung • Ketuk untuk Sambungkan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: printerState.isConnected
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── KARTU TENT CARD MODERN (CAPTURE REPAINT BOUNDARY) ──
                Center(
                  child: RepaintBoundary(
                    key: _qrCardKey,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 26,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Cafe
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryLight,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.coffee_rounded,
                              size: 26,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            storeName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Digital Menu & Self-Order POS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Table Badge (jika dipilih)
                          if (currentTable.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentTable.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _currentUrl,
                              version: QrVersions.auto,
                              size: 195,
                              gapless: true,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
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
                          const SizedBox(height: 16),

                          // Footer Kartu
                          const Text(
                            'Arahkan kamera ponsel Anda ke QR Code\nuntuk melihat menu & memesan langsung',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ── ACTION BUTTONS ───────────────────────────
                // 1. Tombol Cetak Cepat ke Thermal Printer
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isPrinting
                        ? null
                        : () => _handlePrintTentCard(storeName),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded, size: 20),
                    label: Text(
                      _isPrinting
                          ? 'Mencetak Tent Card...'
                          : 'Cetak ke Printer Bluetooth',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Tombol Simpan ke Galeri & Salin Link
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveQrToGallery,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                        label: const Text(
                          'Simpan Galeri',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _copyLink,
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        label: const Text(
                          'Salin Tautan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── INFO LINK PREVIEW ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentUrl,
                          style: const TextStyle(
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
