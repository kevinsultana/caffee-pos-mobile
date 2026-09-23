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

class QrTableScreen extends ConsumerStatefulWidget {
  const QrTableScreen({super.key});

  @override
  ConsumerState<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends ConsumerState<QrTableScreen> {
  final TextEditingController _tableController = TextEditingController(
    text: 'Meja 01',
  );
  final GlobalKey _qrCardKey = GlobalKey();

  String _currentTable = 'Meja 01';
  bool _isSaving = false;

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  void _generateQr() {
    FocusScope.of(context).unfocus();
    final input = _tableController.text.trim();
    if (input.isNotEmpty) {
      setState(() {
        _currentTable = input;
      });
    }
  }

  String _buildMenuUrl(String table) {
    final encodedTable = Uri.encodeComponent(table);
    return 'https://caffee-pos.vercel.app/menu?table=$encodedTable';
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);

    try {
      // Delay singkat untuk memastikan RepaintBoundary ter-render sempurna dengan resolusi penuh
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

      // Sanitasi nama file agar valid di filesystem
      final cleanFileName =
          'QR_${_currentTable.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}';

      // Simpan ke galeri menggunakan package Gal (MediaStore API modern)
      await Gal.putImageBytes(pngBytes, name: cleanFileName);

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppToast.showSuccess(
        context,
        'QR Code $_currentTable berhasil disimpan ke Galeri!',
        duration: const Duration(seconds: 3),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      String errorMessage = 'Gagal menyimpan gambar ke galeri.';
      if (e.type == GalExceptionType.accessDenied) {
        errorMessage = 'Izin akses galeri ditolak. Harap izinkan akses penyimpanan di Pengaturan Aplikasi.';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final printerState = ref.watch(printerProvider);
    final storeName = authState.storeName.isNotEmpty
        ? authState.storeName
        : 'SCHAW CAFE';
    final qrUrl = _buildMenuUrl(_currentTable);

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
                // 1. Form Input Nomor Meja
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nama atau Nomor Meja',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tableController,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _generateQr(),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: Meja 01, VIP 2, Outdoor 3',
                                  prefixIcon: const Icon(
                                    Icons.table_restaurant_rounded,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _generateQr,
                                child: const Text('Terapkan'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Preset chips meja
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children:
                              [
                                'Meja 01',
                                'Meja 02',
                                'Meja 03',
                                'Meja 04',
                                'VIP 1',
                                'Outdoor 1',
                              ].map((t) {
                                return ActionChip(
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: _currentTable == t
                                      ? AppColors.primaryContainer
                                      : AppColors.surfaceMuted,
                                  side: BorderSide(
                                    color: _currentTable == t
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                  onPressed: () {
                                    _tableController.text = t;
                                    _generateQr();
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. KARTU TENT CARD MEJA (Dibungkus RepaintBoundary untuk Capture)
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

                          // QR Code Container
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
                              data: qrUrl,
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

                          // Badge Nomor Meja
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primaryLight),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'NOMOR MEJA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentTable.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

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

                // 3. Tombol Aksi Simpan & Cetak
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

                    // Tampilkan konfirmasi kirim ke printer
                    AppToast.showInfo(
                      context,
                      'Mengirim data Tent Card $_currentTable ke printer thermal...',
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

                // Link URL info
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
                          qrUrl,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
