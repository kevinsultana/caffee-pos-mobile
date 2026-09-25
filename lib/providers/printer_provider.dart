import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/bluetooth_printer_service.dart';

@immutable
class PrinterState {
  final bool isScanning;
  final bool isConnected;
  final bool isPrinting;
  final List<BluetoothInfo> devices;
  final BluetoothInfo? connectedDevice;
  final String? statusMessage;

  const PrinterState({
    this.isScanning = false,
    this.isConnected = false,
    this.isPrinting = false,
    this.devices = const [],
    this.connectedDevice,
    this.statusMessage,
  });

  PrinterState copyWith({
    bool? isScanning,
    bool? isConnected,
    bool? isPrinting,
    List<BluetoothInfo>? devices,
    BluetoothInfo? Function()? connectedDevice,
    String? Function()? statusMessage,
  }) {
    return PrinterState(
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      isPrinting: isPrinting ?? this.isPrinting,
      devices: devices ?? this.devices,
      connectedDevice: connectedDevice != null ? connectedDevice() : this.connectedDevice,
      statusMessage: statusMessage != null ? statusMessage() : this.statusMessage,
    );
  }
}

class PrinterNotifier extends Notifier<PrinterState> {
  @override
  PrinterState build() {
    Future.microtask(() => checkConnectionStatus());
    return const PrinterState();
  }

  /// Cek status koneksi printer saat ini
  Future<void> checkConnectionStatus() async {
    final connected = await BluetoothPrinterService.isConnected();
    state = state.copyWith(isConnected: connected);
  }

  /// Pindai (scan) perangkat Bluetooth yang terpasang di perangkat
  Future<void> scanDevices() async {
    state = state.copyWith(isScanning: true, statusMessage: () => 'Memindai perangkat Bluetooth...');

    final isPermitted = await BluetoothPrinterService.checkPermission();
    if (!isPermitted) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: () => 'Izin Bluetooth belum diberikan di perangkat ini.',
      );
      return;
    }

    final isEnabled = await BluetoothPrinterService.isBluetoothEnabled();
    if (!isEnabled) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: () => 'Bluetooth ponsel sedang mati. Harap aktifkan Bluetooth.',
      );
      return;
    }

    final pairedList = await BluetoothPrinterService.getPairedDevices();
    final connected = await BluetoothPrinterService.isConnected();

    state = state.copyWith(
      isScanning: false,
      devices: pairedList,
      isConnected: connected,
      statusMessage: () => pairedList.isEmpty
          ? 'Tidak ada printer Bluetooth yang terpasang (paired).'
          : 'Ditemukan ${pairedList.length} perangkat Bluetooth.',
    );
  }

  /// Sambungkan ke printer yang dipilih
  Future<bool> connectDevice(BluetoothInfo device) async {
    state = state.copyWith(statusMessage: () => 'Menghubungkan ke ${device.name}...');

    final success = await BluetoothPrinterService.connect(device.macAdress);

    if (success) {
      state = state.copyWith(
        isConnected: true,
        connectedDevice: () => device,
        statusMessage: () => 'Terhubung ke ${device.name}',
      );
      return true;
    } else {
      state = state.copyWith(
        isConnected: false,
        statusMessage: () => 'Gagal menghubungkan ke ${device.name}. Pastikan printer menyala.',
      );
      return false;
    }
  }

  /// Putuskan sambungan dari printer
  Future<void> disconnectDevice() async {
    await BluetoothPrinterService.disconnect();
    state = state.copyWith(
      isConnected: false,
      connectedDevice: () => null,
      statusMessage: () => 'Printer terputus.',
    );
  }

  /// Cetak struk pesanan
  Future<bool> printReceipt(
    OrderModel order, {
    String storeName = 'SCHAW CAFE',
    String? cashierName,
    StoreSettingsModel? settings,
  }) async {
    if (!state.isConnected) {
      state = state.copyWith(statusMessage: () => 'Printer belum terhubung.');
      return false;
    }

    state = state.copyWith(isPrinting: true);
    final success = await BluetoothPrinterService.printReceipt(
      order,
      storeName: storeName,
      cashierName: cashierName,
      settings: settings,
    );
    state = state.copyWith(isPrinting: false);
    return success;
  }

  /// Cetak tiket dapur (kitchen ticket)
  Future<bool> printKitchenTicket(OrderModel order) async {
    if (!state.isConnected) {
      state = state.copyWith(statusMessage: () => 'Printer belum terhubung.');
      return false;
    }

    state = state.copyWith(isPrinting: true);
    final success = await BluetoothPrinterService.printKitchenTicket(order);
    state = state.copyWith(isPrinting: false);
    return success;
  }

  /// Cetak struk pengujian (test print)
  Future<bool> printTestReceipt({
    String storeName = 'SCHAW CAFE',
    StoreSettingsModel? settings,
  }) async {
    if (!state.isConnected) return false;

    state = state.copyWith(isPrinting: true);
    final success = await BluetoothPrinterService.printTestReceipt(
      storeName: storeName,
      settings: settings,
    );
    state = state.copyWith(isPrinting: false);
    return success;
  }

  /// Cetak Tent Card Meja / QR Menu
  Future<bool> printQrTentCard({
    required String qrUrl,
    String storeName = 'SCHAW CAFE',
    String? tableNumber,
  }) async {
    if (!state.isConnected) {
      state = state.copyWith(statusMessage: () => 'Printer belum terhubung.');
      return false;
    }

    state = state.copyWith(isPrinting: true);
    final success = await BluetoothPrinterService.printQrTentCard(
      qrUrl: qrUrl,
      storeName: storeName,
      tableNumber: tableNumber,
    );
    state = state.copyWith(isPrinting: false);
    return success;
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterState>(PrinterNotifier.new);
