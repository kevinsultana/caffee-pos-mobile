import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/order_model.dart';

class BluetoothPrinterService {
  /// Cek izin Bluetooth perangkat
  static Future<bool> checkPermission() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah Bluetooth ponsel sedang aktif
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Ambil daftar printer bluetooth yang sudah terpasang (paired)
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  /// Hubungkan ke printer melalui MAC Address
  static Future<bool> connect(String macAddress) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (_) {
      return false;
    }
  }

  /// Putuskan koneksi printer
  static Future<bool> disconnect() async {
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
      return false;
    }
  }

  /// Cek status koneksi saat ini
  static Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Helper untuk menyusun baris teks dengan rata kiri & kanan (panjang 32 karakter untuk printer 58mm)
  static String _formatRow(String left, String right, {int width = 32}) {
    final availableSpace = width - left.length - right.length;
    if (availableSpace <= 0) {
      return '$left $right\n';
    }
    return '$left${' ' * availableSpace}$right\n';
  }

  /// Cetak struk pesanan kasir menggunakan perintah standar ESC/POS
  static Future<bool> printReceipt(
    OrderModel order, {
    String storeName = 'SCHAW CAFE',
    String? cashierName,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final bytes = <int>[];

    // ── Command ESC/POS Dasar ─────────────────────────────────────────────
    const escInit = [27, 64]; // Reset printer
    const alignCenter = [27, 97, 1]; // Rata tengah
    const alignLeft = [27, 97, 0]; // Rata kiri
    const boldOn = [27, 69, 1]; // Tebal aktif
    const boldOff = [27, 69, 0]; // Tebal mati
    const textDouble = [29, 33, 17]; // Ukuran teks 2x
    const textNormal = [29, 33, 0]; // Ukuran teks normal
    const lineFeed = [10]; // Newline

    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // 1. Inisialisasi
    bytes.addAll(escInit);

    // 2. Header Toko (Center & Bold)
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    bytes.addAll(textDouble);
    bytes.addAll(utf8.encode('$storeName\n'));
    bytes.addAll(textNormal);
    bytes.addAll(boldOff);
    bytes.addAll(utf8.encode('Point of Sale & Coffee Bar\n'));
    bytes.addAll(utf8.encode('================================\n'));

    // 3. Info Transaksi (Rata Kiri)
    bytes.addAll(alignLeft);
    bytes.addAll(utf8.encode('No. Order : ${order.orderNumber}\n'));
    if (order.queueNumber != null) {
      bytes.addAll(boldOn);
      bytes.addAll(
        utf8.encode(
          'Antrean   : ${order.queueNumber} (${order.diningLabel})\n',
        ),
      );
      bytes.addAll(boldOff);
    }
    bytes.addAll(utf8.encode('Waktu     : ${order.formattedDate}\n'));
    if (cashierName != null || order.cashierName != null) {
      bytes.addAll(
        utf8.encode('Kasir     : ${cashierName ?? order.cashierName}\n'),
      );
    }
    bytes.addAll(utf8.encode('Pelanggan : ${order.customerNameSnapshot}\n'));
    bytes.addAll(utf8.encode('--------------------------------\n'));

    // 4. Daftar Item Pesanan
    bytes.addAll(boldOn);
    bytes.addAll(utf8.encode(_formatRow('MENU', 'TOTAL')));
    bytes.addAll(boldOff);
    bytes.addAll(utf8.encode('--------------------------------\n'));

    for (final item in order.items) {
      bytes.addAll(utf8.encode('${item.productNameSnapshot}\n'));
      if (item.variantNameSnapshot != null &&
          item.variantNameSnapshot!.isNotEmpty) {
        bytes.addAll(utf8.encode('  (${item.variantNameSnapshot})\n'));
      }
      final priceDetail =
          '${item.quantity} x ${currencyFmt.format(item.unitPrice)}';
      bytes.addAll(
        utf8.encode(
          _formatRow('  $priceDetail', currencyFmt.format(item.subtotal)),
        ),
      );

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(utf8.encode('  * ${item.notes}\n'));
      }
    }

    bytes.addAll(utf8.encode('--------------------------------\n'));

    // 5. Total Pembayaran
    bytes.addAll(
      _formatRow(
        'Subtotal',
        currencyFmt.format(order.productSubtotal),
      ).codeUnits,
    );
    bytes.addAll(boldOn);
    bytes.addAll(
      _formatRow('TOTAL', currencyFmt.format(order.grandTotal)).codeUnits,
    );
    bytes.addAll(boldOff);

    // 6. Rincian Metode Bayar
    final payment = order.payment;
    if (payment != null) {
      bytes.addAll(_formatRow('Metode Bayar', payment.method).codeUnits);
      if (payment.method == 'CASH' && payment.cashReceived != null) {
        bytes.addAll(
          _formatRow(
            'Bayar Tunai',
            currencyFmt.format(payment.cashReceived!),
          ).codeUnits,
        );
        if (payment.changeAmount != null) {
          bytes.addAll(
            _formatRow(
              'Kembalian',
              currencyFmt.format(payment.changeAmount!),
            ).codeUnits,
          );
        }
      }
    }

    bytes.addAll(utf8.encode('================================\n'));

    // 7. Footer Struk
    bytes.addAll(alignCenter);
    bytes.addAll(utf8.encode('Terima Kasih Atas Kunjungan Anda\n'));
    bytes.addAll(utf8.encode('Silakan Berkunjung Kembali!\n'));
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed); // Feed paper agar struk bisa disobek

    // Kirim bytes ke printer thermal
    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Cetak tiket dapur (kitchen ticket) menggunakan perintah standar ESC/POS
  static Future<bool> printKitchenTicket(OrderModel order) async {
    final connected = await isConnected();
    if (!connected) return false;

    final bytes = <int>[];

    // ── Command ESC/POS Dasar ─────────────────────────────────────────────
    const escInit = [27, 64]; // Reset printer
    const alignCenter = [27, 97, 1]; // Rata tengah
    const alignLeft = [27, 97, 0]; // Rata kiri
    const boldOn = [27, 69, 1]; // Tebal aktif
    const boldOff = [27, 69, 0]; // Tebal mati
    const textDoubleHeight = [29, 33, 16]; // Double height (GS ! 16)
    const textDoubleBoth = [
      29,
      33,
      17,
    ]; // Double width + double height (GS ! 17)
    const textNormal = [29, 33, 0]; // Ukuran teks normal
    const lineFeed = [10]; // Newline

    // 1. Inisialisasi
    bytes.addAll(escInit);

    // 2. Header Tiket Dapur (Center & Bold)
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    bytes.addAll(textDoubleHeight);
    bytes.addAll(utf8.encode('== TIKET DAPUR ==\n'));
    bytes.addAll(textNormal);

    final queueNum = order.queueNumber ?? '-';
    final isTakeaway = !order.isDineIn;
    final typeBadge = isTakeaway
        ? '[ BUNGKUS / TAKEAWAY ]'
        : '[ DINE IN / DI TEMPAT ]';
    bytes.addAll(utf8.encode('$typeBadge\n'));
    bytes.addAll(boldOff);
    bytes.addAll(utf8.encode('================================\n'));

    // 3. Nomor Antrean Besar & Jelas untuk Dapur
    if (queueNum.isNotEmpty && queueNum != '-') {
      bytes.addAll(alignCenter);
      bytes.addAll(utf8.encode('NOMOR ANTREAN\n'));
      bytes.addAll(boldOn);
      bytes.addAll(textDoubleBoth);
      bytes.addAll(utf8.encode('$queueNum\n'));
      bytes.addAll(textNormal);
      bytes.addAll(boldOff);
      bytes.addAll(utf8.encode('--------------------------------\n'));
    }

    // 4. Meta Order (Rata Kiri)
    bytes.addAll(alignLeft);
    bytes.addAll(utf8.encode('No. Order : ${order.orderNumber}\n'));
    bytes.addAll(utf8.encode('Waktu     : ${order.formattedDate}\n'));
    final custName = order.customerNameSnapshot.trim().isNotEmpty
        ? order.customerNameSnapshot
        : 'Umum';
    bytes.addAll(utf8.encode('Pelanggan : $custName\n'));
    bytes.addAll(
      utf8.encode(
        'Tipe      : ${isTakeaway ? 'Takeaway / Bungkus' : 'Dine In / Di Tempat'}\n',
      ),
    );
    bytes.addAll(
      utf8.encode(
        'Sumber    : ${order.source == 'PUBLIC_QR' ? 'QR Online' : 'Kasir POS'}\n',
      ),
    );
    bytes.addAll(utf8.encode('--------------------------------\n'));

    // 5. Items Pesanan (Dapur — TANPA HARGA)
    for (final item in order.items) {
      bytes.addAll(boldOn);
      bytes.addAll(
        utf8.encode('${item.quantity}x ${item.productNameSnapshot}\n'),
      );
      bytes.addAll(boldOff);

      if (item.variantNameSnapshot != null &&
          item.variantNameSnapshot!.isNotEmpty) {
        bytes.addAll(utf8.encode('   Varian: ${item.variantNameSnapshot}\n'));
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(utf8.encode('   *Catatan: ${item.notes}\n'));
      }
    }

    bytes.addAll(utf8.encode('================================\n'));

    // 6. Penutup Tiket Dapur
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    bytes.addAll(utf8.encode('*** SELESAIKAN PESANAN ***\n'));
    bytes.addAll(boldOff);
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed); // Feed paper agar tiket bisa disobek

    // Kirim bytes ke printer thermal
    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Cetak struk pengujian printer thermal
  static Future<bool> printTestReceipt({
    String storeName = 'SCHAW CAFE',
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final bytes = <int>[];
    bytes.addAll([27, 64]); // Init
    bytes.addAll([27, 97, 1]); // Center
    bytes.addAll([27, 69, 1]); // Bold
    bytes.addAll(utf8.encode('$storeName\n'));
    bytes.addAll([27, 69, 0]); // Bold off
    bytes.addAll(utf8.encode('UJI COBA PRINTER BERHASIL\n'));
    bytes.addAll(utf8.encode('Koneksi Bluetooth Berjalan Lancar\n'));
    bytes.addAll(utf8.encode('--------------------------------\n'));
    bytes.addAll(utf8.encode('${DateTime.now().toLocal()}\n'));
    bytes.addAll([10, 10, 10]);

    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}
