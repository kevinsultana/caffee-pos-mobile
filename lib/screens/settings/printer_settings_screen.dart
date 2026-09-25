import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/store_settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/store_settings_provider.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  late final TextEditingController _headerController;
  late final TextEditingController _footerController;

  int _printerWidth = 58;
  bool _showLogo = true;
  bool _showStoreName = true;
  String _headerAlign = 'CENTER';
  bool _headerBold = false;
  String _footerAlign = 'CENTER';
  bool _footerBold = false;
  bool _doubleHeight = true;
  String _fontSize = 'NORMAL';

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _headerController = TextEditingController();
    _footerController = TextEditingController();

    // Pastikan data pengaturan terbaru termasuk receiptLogoUrl selalu ter-fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.storeId.isNotEmpty) {
        ref.read(storeSettingsProvider.notifier).fetchSettings(auth.storeId);
      }
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _syncFromSettings(StoreSettingsModel settings) {
    _printerWidth = settings.printerWidth;
    _showLogo = settings.receiptShowLogo;
    _showStoreName = settings.receiptShowStoreName;
    _headerAlign = settings.receiptHeaderAlign;
    _headerBold = settings.receiptHeaderBold;
    _footerAlign = settings.receiptFooterAlign;
    _footerBold = settings.receiptFooterBold;
    _doubleHeight = settings.receiptDoubleHeight;
    _fontSize = settings.receiptFontSize;
    _headerController.text = settings.receiptHeader ?? '';
    _footerController.text = settings.receiptFooter ?? '';
    _isInitialized = true;
  }

  StoreSettingsModel _buildCurrentSettings(StoreSettingsModel base) {
    return base.copyWith(
      printerWidth: _printerWidth,
      receiptShowLogo: _showLogo,
      receiptShowStoreName: _showStoreName,
      receiptHeader: _headerController.text.trim().isEmpty ? null : _headerController.text.trim(),
      receiptHeaderAlign: _headerAlign,
      receiptHeaderBold: _headerBold,
      receiptFooter: _footerController.text.trim().isEmpty ? null : _footerController.text.trim(),
      receiptFooterAlign: _footerAlign,
      receiptFooterBold: _footerBold,
      receiptDoubleHeight: _doubleHeight,
      receiptFontSize: _fontSize,
    );
  }

  Future<void> _handleSaveSettings() async {
    final settingsState = ref.read(storeSettingsProvider);
    final updated = _buildCurrentSettings(settingsState.settings);

    final error = await ref.read(storeSettingsProvider.notifier).updateSettings(updated);
    if (!mounted) return;

    if (error == null) {
      AppToast.showSuccess(context, 'Pengaturan struk berhasil disimpan ke sistem!');
    } else {
      AppToast.showError(context, error);
    }
  }

  Future<void> _handleTestPrint() async {
    final printerState = ref.read(printerProvider);
    if (!printerState.isConnected) {
      AppToast.showWarning(context, 'Printer belum tersambung. Sambungkan ke printer Bluetooth terlebih dahulu.');
      return;
    }

    final authState = ref.read(authProvider);
    final settingsState = ref.read(storeSettingsProvider);
    final currentSettings = _buildCurrentSettings(settingsState.settings);

    final success = await ref.read(printerProvider.notifier).printTestReceipt(
          storeName: authState.storeName.isNotEmpty ? authState.storeName : 'SCHAW CAFE',
          settings: currentSettings,
        );

    if (!mounted) return;
    if (success) {
      AppToast.showSuccess(context, 'Uji cetak berhasil dikirim ke printer!');
    } else {
      AppToast.showError(context, 'Gagal mencetak. Pastikan printer menyala & memiliki kertas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);
    final storeSettingsState = ref.watch(storeSettingsProvider);

    // Otomatis sinkronisasi form ketika data database berhasil dimuat pertama kali
    ref.listen<StoreSettingsState>(storeSettingsProvider, (prev, next) {
      if ((prev == null || prev.isLoading) && !next.isLoading) {
        setState(() {
          _syncFromSettings(next.settings);
        });
      }
    });

    if (!_isInitialized && !storeSettingsState.isLoading) {
      _syncFromSettings(storeSettingsState.settings);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Printer & Struk'),
        actions: [
          IconButton(
            tooltip: 'Pindai Ulang Bluetooth',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: printerState.isScanning
                ? null
                : () => ref.read(printerProvider.notifier).scanDevices(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ═════════════════════════════════════════════════════════════════
          // 1. SECTION STATUS KONEKSI PRINTER
          // ═════════════════════════════════════════════════════════════════
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: printerState.isConnected
                          ? AppColors.primaryContainer
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: printerState.isConnected
                            ? AppColors.primaryLight
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      printerState.isConnected
                          ? Icons.print_rounded
                          : Icons.print_disabled_rounded,
                      color: printerState.isConnected
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: printerState.isConnected
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                printerState.isConnected
                                    ? 'Printer Terhubung'
                                    : 'Printer Belum Terhubung',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          printerState.connectedDevice != null
                              ? '${printerState.connectedDevice!.name} (${printerState.connectedDevice!.macAdress})'
                              : 'Pilih printer thermal bluetooth dari daftar di bawah untuk menyambungkan.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ═════════════════════════════════════════════════════════════════
          // 2. DAFTAR PERANGKAT BLUETOOTH
          // ═════════════════════════════════════════════════════════════════
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Perangkat Bluetooth Terpasang',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: printerState.isScanning
                    ? null
                    : () => ref.read(printerProvider.notifier).scanDevices(),
                icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                label: Text(printerState.isScanning ? 'Memindai...' : 'Pindai'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (printerState.isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (printerState.devices.isEmpty)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Tidak Ada Printer Terdeteksi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pastikan printer thermal Bluetooth Anda telah dinyalakan dan di-pairing di Pengaturan Ponsel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...printerState.devices.map((device) {
              final isCurrent = printerState.connectedDevice?.macAdress == device.macAdress &&
                  printerState.isConnected;

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCurrent ? AppColors.primary : AppColors.border,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primaryContainer : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    device.name.isNotEmpty ? device.name : 'Printer Thermal',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    device.macAdress,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: isCurrent
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              ref.read(printerProvider.notifier).disconnectDevice(),
                          child: const Text('Putus'),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await ref
                                .read(printerProvider.notifier)
                                .connectDevice(device);
                            if (context.mounted) {
                              if (ok) {
                                AppToast.showSuccess(
                                  context,
                                  'Berhasil tersambung ke ${device.name}',
                                );
                              } else {
                                AppToast.showError(
                                  context,
                                  'Gagal tersambung ke ${device.name}',
                                );
                              }
                            }
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Sambungkan'),
                          ),
                        ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // ═════════════════════════════════════════════════════════════════
          // 3. SECTION FORMAT KERTAS & STRUK KASIR
          // ═════════════════════════════════════════════════════════════════
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 20,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Format Kertas & Struk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Kustomisasi tata letak, ukuran, dan pesan nota struk kasir.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── LEBAR KERTAS ──
                  const Text(
                    'LEBAR KERTAS PRINTER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 58,
                          label: Text('58 mm (32 Kolom)'),
                          icon: Icon(Icons.receipt_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 80,
                          label: Text('80 mm (48 Kolom)'),
                          icon: Icon(Icons.receipt_long_rounded, size: 16),
                        ),
                      ],
                      selected: {_printerWidth},
                      onSelectionChanged: (newSelection) {
                        setState(() => _printerWidth = newSelection.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _printerWidth == 58
                        ? 'Cocok untuk printer saku Bluetooth portabel standar (32 karakter/baris).'
                        : 'Cocok untuk printer kasir desktop atau standar resto (48 karakter/baris).',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 20),

                  // ── HEADER & IDENTITAS ──
                  const Text(
                    'HEADER & IDENTITAS STRUK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tampilkan Nama Toko',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Cetak nama usaha di bagian paling atas struk.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: _showStoreName,
                    onChanged: (val) => setState(() => _showStoreName = val),
                    activeTrackColor: AppColors.primary,
                  ),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tampilkan Logo Struk',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Sertakan gambar logo jika printer mendukung cetak raster grafik.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: _showLogo,
                    onChanged: (val) => setState(() => _showLogo = val),
                    activeTrackColor: AppColors.primary,
                  ),

                  if (_showLogo) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          if (storeSettingsState.settings.receiptLogoUrl != null &&
                              storeSettingsState.settings.receiptLogoUrl!.trim().isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: Colors.white,
                                padding: const EdgeInsets.all(2),
                                child: CachedNetworkImage(
                                  imageUrl: storeSettingsState.settings.receiptLogoUrl!.trim(),
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.broken_image_rounded,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logo Struk Aktif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Logo akan otomatis dicetak di atas nama toko pada struk pelanggan.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: AppColors.amber,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Belum ada logo struk yang diunggah. Unggah foto logo di menu Pengaturan Struk pada Web App.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Huruf Tinggi (Double Height)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Cetak teks nama usaha dan TOTAL transaksi 2x lebih tinggi.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: _doubleHeight,
                    onChanged: (val) => setState(() => _doubleHeight = val),
                    activeTrackColor: AppColors.primary,
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _headerController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Header / Catatan Atas Struk',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Contoh:\nJl. Sudirman No. 12, Jakarta\nTelp/WA: 0812-3456-7890\nInstagram: @schawcafe',
                      hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),

                  const SizedBox(height: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rata Teks Header:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _buildAlignSelector(
                          currentAlign: _headerAlign,
                          onChanged: (align) => setState(() => _headerAlign = align),
                        ),
                      ),
                    ],
                  ),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Teks Header Tebal (Bold)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: _headerBold,
                    onChanged: (val) => setState(() => _headerBold = val),
                    activeTrackColor: AppColors.primary,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 20),

                  // ── FOOTER & PESAN PENUTUP ──
                  const Text(
                    'FOOTER & PESAN PENUTUP STRUK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _footerController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Footer / Pesan Bawah Struk',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Contoh:\nTerima kasih atas kunjungan Anda!\nWifi: kopienak / pass: nikmat123\nSimpan struk sebagai bukti pembayaran sah.',
                      hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),

                  const SizedBox(height: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rata Teks Footer:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _buildAlignSelector(
                          currentAlign: _footerAlign,
                          onChanged: (align) => setState(() => _footerAlign = align),
                        ),
                      ),
                    ],
                  ),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Teks Footer Tebal (Bold)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: _footerBold,
                    onChanged: (val) => setState(() => _footerBold = val),
                    activeTrackColor: AppColors.primary,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 20),

                  // ── UKURAN FONT STRUK ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ukuran Font Struk',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Font A (standar) atau Font B (kompak/hemat kertas)',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'NORMAL',
                              label: Text('Normal (Font A)'),
                              icon: Icon(Icons.text_fields_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'SMALL',
                              label: Text('Kecil (Font B)'),
                              icon: Icon(Icons.compress_rounded, size: 16),
                            ),
                          ],
                          selected: {_fontSize},
                          onSelectionChanged: (newSelection) {
                            setState(() => _fontSize = newSelection.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── TOMBOL AKSI: SIMPAN & TEST PRINT ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: storeSettingsState.isSaving ? null : _handleSaveSettings,
                      icon: storeSettingsState.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        storeSettingsState.isSaving
                            ? 'Menyimpan Pengaturan...'
                            : 'Simpan Pengaturan Struk',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (printerState.isPrinting || !printerState.isConnected)
                          ? null
                          : _handleTestPrint,
                      icon: printerState.isPrinting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.print_outlined, size: 20),
                      label: Text(
                        printerState.isConnected
                            ? 'Cetak Struk Percobaan (Test Print)'
                            : 'Sambungkan Printer Untuk Test Print',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ═════════════════════════════════════════════════════════════════
          // 4. PETUNJUK PENGGUNAAN
          // ═════════════════════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Petunjuk Printer Kasir Thermal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. Pastikan Bluetooth aktif dan printer thermal Anda sudah ter-pair di menu Pengaturan Bluetooth ponsel.\n'
                  '2. Tekan tombol "Pindai" lalu pilih nama printer Anda dan klik "Sambungkan".\n'
                  '3. Sesuaikan lebar kertas (58mm untuk printer mini atau 80mm untuk printer desktop).\n'
                  '4. Isi catatan header toko (alamat/telepon) dan footer (ucapan terima kasih/WiFi).\n'
                  '5. Klik "Simpan Pengaturan Struk" agar konfigurasi ini tersinkronisasi di cloud & berlaku untuk seluruh pesanan POS.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlignSelector({
    required String currentAlign,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'LEFT',
          label: Text('Kiri', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.format_align_left_rounded, size: 14),
        ),
        ButtonSegment(
          value: 'CENTER',
          label: Text('Tengah', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.format_align_center_rounded, size: 14),
        ),
        ButtonSegment(
          value: 'RIGHT',
          label: Text('Kanan', style: TextStyle(fontSize: 11)),
          icon: Icon(Icons.format_align_right_rounded, size: 14),
        ),
      ],
      selected: {currentAlign},
      onSelectionChanged: (Set<String> newSelection) {
        onChanged(newSelection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
