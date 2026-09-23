import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Printer Thermal'),
        actions: [
          IconButton(
            tooltip: 'Pindai Ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: printerState.isScanning
                ? null
                : () => ref.read(printerProvider.notifier).scanDevices(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Status Card
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
                        Text(
                          printerState.isConnected
                              ? 'Printer Terhubung'
                              : 'Printer Belum Terhubung',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          printerState.connectedDevice != null
                              ? '${printerState.connectedDevice!.name} (${printerState.connectedDevice!.macAdress})'
                              : 'Pilih printer bluetooth dari daftar di bawah untuk menyambungkan.',
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

          // Tombol Uji Cetak (Test Print)
          if (printerState.isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: printerState.isPrinting
                      ? null
                      : () async {
                          final success = await ref
                              .read(printerProvider.notifier)
                              .printTestReceipt(
                                storeName: authState.storeName.isNotEmpty
                                    ? authState.storeName
                                    : 'SCHAW CAFE',
                              );
                          if (context.mounted) {
                            if (success) {
                              AppToast.showSuccess(
                                context,
                                'Uji cetak berhasil dikirim ke printer!',
                              );
                            } else {
                              AppToast.showError(
                                context,
                                'Gagal mencetak. Periksa kertas & bluetooth printer.',
                              );
                            }
                          }
                        },
                  icon: printerState.isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long_rounded, size: 20),
                  label: const Text(
                    'Uji Cetak Struk (Test Print)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // 2. Daftar Perangkat Bluetooth
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Perangkat Bluetooth Terpasang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
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
                padding: EdgeInsets.all(32),
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
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tidak Ada Printer Terdeteksi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pastikan printer thermal Bluetooth Anda telah dinyalakan dan di-pairing melalui Pengaturan Bluetooth Android.',
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

          // Petunjuk
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
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
                      'Petunjuk Printer Kasir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '1. Nyalakan printer thermal Bluetooth Anda (standar 58mm / 80mm).\n'
                  '2. Masuk ke Pengaturan Bluetooth ponsel Anda dan lakukan Pair.\n'
                  '3. Kembali ke halaman ini dan tekan tombol "Pindai" lalu "Sambungkan".\n'
                  '4. Tekan "Uji Cetak Struk" untuk memastikan struk keluar dengan rapi.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
