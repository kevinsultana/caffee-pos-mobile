import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';

class BluetoothPrinterService {
  /// Cache ESC/POS raster image bytes agar tidak perlu mengunduh ulang gambar yang sama
  static final Map<String, List<int>> _rasterCache = {};

  /// Mengunduh gambar dari [imageUrl] dan mengonversinya menjadi perintah ESC/POS raster bit image (GS v 0).
  /// [maxDots] adalah lebar piksel maksimum (256 untuk 58mm, 384 untuk 80mm).
  static Future<List<int>?> rasterizeImageUrl(
    String imageUrl, {
    int maxDots = 256,
  }) async {
    try {
      final cacheKey = '$imageUrl@$maxDots';
      if (_rasterCache.containsKey(cacheKey)) {
        return _rasterCache[cacheKey];
      }

      final uri = Uri.tryParse(imageUrl);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return null;
      }

      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      final request = await httpClient.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }

      final imgBytes = await consolidateHttpClientResponseBytes(response);
      if (imgBytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(imgBytes);
      final frameInfo = await codec.getNextFrame();
      final img = frameInfo.image;

      final origW = img.width;
      final origH = img.height;
      if (origW <= 0 || origH <= 0) return null;

      // Batasi lebar maksimum dan pastikan kelipatan 8 dots
      int targetW = origW > maxDots ? maxDots : origW;
      targetW = (targetW ~/ 8) * 8;
      if (targetW < 8) targetW = 8;
      final targetH = ((origH * targetW) / origW).round();
      if (targetH <= 0) return null;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      // Background putih solid (khusus PNG transparan agar tidak jadi hitam pekat)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, origW.toDouble(), origH.toDouble()),
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final picture = pictureRecorder.endRecording();
      final renderedImg = await picture.toImage(targetW, targetH);
      final byteData =
          await renderedImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final rawBytes = byteData.buffer.asUint8List();
      final bytesWidth = targetW ~/ 8;
      final xL = bytesWidth & 0xff;
      final xH = (bytesWidth >> 8) & 0xff;
      final yL = targetH & 0xff;
      final yH = (targetH >> 8) & 0xff;

      // Header ESC/POS Raster Bit Image: GS v 0 0 xL xH yL yH
      final rasterBytes = <int>[
        29, 118, 48, 0, // GS v 0 0
        xL, xH,
        yL, yH,
      ];

      for (int y = 0; y < targetH; y++) {
        for (int b = 0; b < bytesWidth; b++) {
          int byteVal = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = b * 8 + bit;
            final idx = (y * targetW + x) * 4;
            final r = rawBytes[idx];
            final g = rawBytes[idx + 1];
            final bl = rawBytes[idx + 2];
            final a = rawBytes[idx + 3];

            // Jika transparan (a < 128) -> putih (255)
            final lum =
                a < 128 ? 255.0 : (0.299 * r + 0.587 * g + 0.114 * bl);
            if (lum < 165) {
              byteVal |= (0x80 >> bit);
            }
          }
          rasterBytes.add(byteVal);
        }
      }

      // Bersihkan resource image
      img.dispose();
      picture.dispose();
      renderedImg.dispose();

      _rasterCache[cacheKey] = rasterBytes;
      return rasterBytes;
    } catch (e) {
      debugPrint('[BluetoothPrinterService] Gagal rasterize logo: $e');
      return null;
    }
  }

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

  /// Helper untuk menyusun baris teks dengan rata kiri & kanan sesuai lebar kolom (32 / 48)
  static String _formatRow(String left, String right, {int width = 32}) {
    final availableSpace = width - left.length - right.length;
    if (availableSpace <= 0) {
      return '$left $right\n';
    }
    return '$left${' ' * availableSpace}$right\n';
  }

  /// Cetak struk pesanan kasir menggunakan perintah standar ESC/POS dinamis sesuai StoreSettings
  static Future<bool> printReceipt(
    OrderModel order, {
    String storeName = 'SCHAW CAFE',
    String? cashierName,
    StoreSettingsModel? settings,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final bytes = <int>[];
    final cols = settings?.effectiveCols ?? 32;
    final sep = '-' * cols;
    final doubleSep = '=' * cols;

    // ── Command ESC/POS Dasar ─────────────────────────────────────────────
    const escInit = [27, 64]; // Reset printer
    const alignLeft = [27, 97, 0]; // Rata kiri
    const alignCenter = [27, 97, 1]; // Rata tengah
    const alignRight = [27, 97, 2]; // Rata kanan
    const boldOn = [27, 69, 1]; // Tebal aktif
    const boldOff = [27, 69, 0]; // Tebal mati
    const textDoubleBoth = [29, 33, 17]; // Ukuran teks 2x (lebar & tinggi)
    const textDoubleHeight = [29, 33, 16]; // Double height
    const textNormal = [29, 33, 0]; // Ukuran teks normal
    const lineFeed = [10]; // Newline

    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // 1. Inisialisasi
    bytes.addAll(escInit);

    // Font Size (Font B jika SMALL)
    if (settings?.receiptFontSize == 'SMALL') {
      bytes.addAll([27, 77, 1]); // Font B
    }

    // ── 1. LOGO STRUK (di atas Header jika diaktifkan & URL logo tersedia) ─
    final logoUrl = settings?.receiptLogoUrl;
    if ((settings?.receiptShowLogo ?? true) &&
        logoUrl != null &&
        logoUrl.trim().isNotEmpty) {
      try {
        final maxDots = (settings?.printerWidth == 80) ? 384 : 256;
        final logoBytes =
            await rasterizeImageUrl(logoUrl.trim(), maxDots: maxDots);
        if (logoBytes != null && logoBytes.isNotEmpty) {
          bytes.addAll(alignCenter);
          bytes.addAll(logoBytes);
          bytes.addAll(lineFeed);
        }
      } catch (err) {
        debugPrint('[BluetoothPrinterService] Gagal cetak logo: $err');
      }
    }

    // 2. Header Nama Toko (jika receiptShowStoreName true)
    if (settings?.receiptShowStoreName ?? true) {
      bytes.addAll(alignCenter);
      bytes.addAll(boldOn);
      if (settings?.receiptDoubleHeight ?? true) {
        bytes.addAll(textDoubleBoth);
      }
      bytes.addAll(utf8.encode('$storeName\n'));
      bytes.addAll(textNormal);
      bytes.addAll(boldOff);
    }

    // 3. Teks Header Kustom (Align & Bold dinamis)
    if (settings?.receiptHeader != null && settings!.receiptHeader!.trim().isNotEmpty) {
      final headerAlign = settings.receiptHeaderAlign == 'LEFT'
          ? alignLeft
          : (settings.receiptHeaderAlign == 'RIGHT' ? alignRight : alignCenter);
      bytes.addAll(headerAlign);
      if (settings.receiptHeaderBold) bytes.addAll(boldOn);

      final headerLines = settings.receiptHeader!.split('\n');
      for (final line in headerLines) {
        if (line.trim().isNotEmpty) {
          bytes.addAll(utf8.encode('${line.trim()}\n'));
        }
      }

      if (settings.receiptHeaderBold) bytes.addAll(boldOff);
    } else {
      bytes.addAll(alignCenter);
      bytes.addAll(utf8.encode('Point of Sale & Coffee Bar\n'));
    }

    bytes.addAll(alignCenter);
    bytes.addAll(utf8.encode('$doubleSep\n'));

    // 4. Info Transaksi (Rata Kiri)
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
    bytes.addAll(utf8.encode('$sep\n'));

    // 5. Daftar Item Pesanan
    bytes.addAll(boldOn);
    bytes.addAll(utf8.encode(_formatRow('MENU', 'TOTAL', width: cols)));
    bytes.addAll(boldOff);
    bytes.addAll(utf8.encode('$sep\n'));

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
          _formatRow('  $priceDetail', currencyFmt.format(item.subtotal), width: cols),
        ),
      );

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(utf8.encode('  * ${item.notes}\n'));
      }
    }

    bytes.addAll(utf8.encode('$sep\n'));

    // 6. Total Pembayaran
    bytes.addAll(
      _formatRow(
        'Subtotal',
        currencyFmt.format(order.productSubtotal),
        width: cols,
      ).codeUnits,
    );
    if (order.promotionDiscount > 0) {
      final promoLabel = (order.promoCodeSnapshot != null && order.promoCodeSnapshot!.isNotEmpty)
          ? 'Diskon Promo (${order.promoCodeSnapshot})'
          : 'Diskon Promo';
      bytes.addAll(
        _formatRow(
          promoLabel,
          '-${currencyFmt.format(order.promotionDiscount)}',
          width: cols,
        ).codeUnits,
      );
    }
    bytes.addAll(boldOn);
    if (settings?.receiptDoubleHeight ?? true) {
      bytes.addAll(textDoubleHeight);
    }
    bytes.addAll(
      _formatRow('TOTAL', currencyFmt.format(order.grandTotal), width: cols).codeUnits,
    );
    bytes.addAll(textNormal);
    bytes.addAll(boldOff);

    // 7. Rincian Metode Bayar
    final payment = order.payment;
    if (payment != null) {
      bytes.addAll(_formatRow('Metode Bayar', payment.method, width: cols).codeUnits);
      if (payment.method == 'CASH' && payment.cashReceived != null) {
        bytes.addAll(
          _formatRow(
            'Bayar Tunai',
            currencyFmt.format(payment.cashReceived!),
            width: cols,
          ).codeUnits,
        );
        if (payment.changeAmount != null) {
          bytes.addAll(
            _formatRow(
              'Kembalian',
              currencyFmt.format(payment.changeAmount!),
              width: cols,
            ).codeUnits,
          );
        }
      }
    }

    bytes.addAll(utf8.encode('$doubleSep\n'));

    // 8. Footer Struk Kustom (Align & Bold dinamis)
    final footerAlign = settings?.receiptFooterAlign == 'LEFT'
        ? alignLeft
        : (settings?.receiptFooterAlign == 'RIGHT' ? alignRight : alignCenter);
    bytes.addAll(footerAlign);

    if (settings?.receiptFooterBold ?? false) bytes.addAll(boldOn);

    if (settings?.receiptFooter != null && settings!.receiptFooter!.trim().isNotEmpty) {
      final footerLines = settings.receiptFooter!.split('\n');
      for (final line in footerLines) {
        if (line.trim().isNotEmpty) {
          bytes.addAll(utf8.encode('${line.trim()}\n'));
        }
      }
    } else {
      bytes.addAll(utf8.encode('Terima Kasih Atas Kunjungan Anda\n'));
      bytes.addAll(utf8.encode('Silakan Berkunjung Kembali!\n'));
    }

    if (settings?.receiptFooterBold ?? false) bytes.addAll(boldOff);

    // Reset font ke normal jika tadi Font B
    if (settings?.receiptFontSize == 'SMALL') {
      bytes.addAll([27, 77, 0]);
    }

    bytes.addAll(alignLeft);
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

  /// Cetak struk pengujian printer thermal dengan konfigurasi StoreSettings
  static Future<bool> printTestReceipt({
    String storeName = 'SCHAW CAFE',
    StoreSettingsModel? settings,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final cols = settings?.effectiveCols ?? 32;
    final sep = '-' * cols;
    final doubleSep = '=' * cols;

    final bytes = <int>[];
    bytes.addAll([27, 64]); // Init

    // Logo Struk Uji Coba jika ada
    final logoUrl = settings?.receiptLogoUrl;
    if ((settings?.receiptShowLogo ?? true) &&
        logoUrl != null &&
        logoUrl.trim().isNotEmpty) {
      try {
        final maxDots = (settings?.printerWidth == 80) ? 384 : 256;
        final logoBytes =
            await rasterizeImageUrl(logoUrl.trim(), maxDots: maxDots);
        if (logoBytes != null && logoBytes.isNotEmpty) {
          bytes.addAll([27, 97, 1]); // Center
          bytes.addAll(logoBytes);
          bytes.addAll([10]);
        }
      } catch (err) {
        debugPrint('[BluetoothPrinterService] Gagal cetak logo test: $err');
      }
    }

    // Header Nama Toko
    bytes.addAll([27, 97, 1]); // Center
    if (settings?.receiptShowStoreName ?? true) {
      bytes.addAll([27, 69, 1]); // Bold
      if (settings?.receiptDoubleHeight ?? true) {
        bytes.addAll([29, 33, 17]);
      }
      bytes.addAll(utf8.encode('$storeName\n'));
      bytes.addAll([29, 33, 0]);
      bytes.addAll([27, 69, 0]);
    }

    // Header Kustom
    if (settings?.receiptHeader != null && settings!.receiptHeader!.trim().isNotEmpty) {
      final alignCode = settings.receiptHeaderAlign == 'LEFT'
          ? 0
          : (settings.receiptHeaderAlign == 'RIGHT' ? 2 : 1);
      bytes.addAll([27, 97, alignCode]);
      if (settings.receiptHeaderBold) bytes.addAll([27, 69, 1]);
      for (final line in settings.receiptHeader!.split('\n')) {
        if (line.trim().isNotEmpty) bytes.addAll(utf8.encode('${line.trim()}\n'));
      }
      if (settings.receiptHeaderBold) bytes.addAll([27, 69, 0]);
    }

    bytes.addAll([27, 97, 1]);
    bytes.addAll(utf8.encode('$doubleSep\n'));
    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode('UJI COBA CETAK STRUK BERHASIL\n'));
    bytes.addAll([27, 69, 0]);
    bytes.addAll(utf8.encode('Koneksi Bluetooth Berjalan Lancar\n'));
    bytes.addAll(utf8.encode('Lebar Kertas: ${settings?.printerWidth ?? 58}mm ($cols Kolom)\n'));
    bytes.addAll(utf8.encode('$sep\n'));

    // Contoh Item
    bytes.addAll(utf8.encode(_formatRow('1x Kopi Susu Aren', 'Rp 22.000', width: cols)));
    bytes.addAll(utf8.encode(_formatRow('1x Croissant Butter', 'Rp 28.000', width: cols)));
    bytes.addAll(utf8.encode('$sep\n'));
    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode(_formatRow('TOTAL', 'Rp 50.000', width: cols)));
    bytes.addAll([27, 69, 0]);
    bytes.addAll(utf8.encode('$doubleSep\n'));

    // Footer Kustom
    final footerAlignCode = settings?.receiptFooterAlign == 'LEFT'
        ? 0
        : (settings?.receiptFooterAlign == 'RIGHT' ? 2 : 1);
    bytes.addAll([27, 97, footerAlignCode]);
    if (settings?.receiptFooterBold ?? false) bytes.addAll([27, 69, 1]);
    if (settings?.receiptFooter != null && settings!.receiptFooter!.trim().isNotEmpty) {
      for (final line in settings.receiptFooter!.split('\n')) {
        if (line.trim().isNotEmpty) bytes.addAll(utf8.encode('${line.trim()}\n'));
      }
    } else {
      bytes.addAll(utf8.encode('Terima Kasih Atas Kunjungan Anda!\n'));
      bytes.addAll(utf8.encode('Simpan struk sebagai bukti pembayaran.\n'));
    }
    if (settings?.receiptFooterBold ?? false) bytes.addAll([27, 69, 0]);

    bytes.addAll([27, 97, 1]);
    bytes.addAll(utf8.encode('${DateTime.now().toLocal().toString().split(".")[0]}\n'));
    bytes.addAll([10, 10, 10]);

    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Cetak Tent Card Meja / QR Menu ke printer thermal bluetooth
  static Future<bool> printQrTentCard({
    required String qrUrl,
    String storeName = 'SCHAW CAFE',
    String? tableNumber,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final bytes = <int>[];

    const escInit = [27, 64]; // Reset printer
    const alignCenter = [27, 97, 1]; // Rata tengah
    const boldOn = [27, 69, 1]; // Tebal aktif
    const boldOff = [27, 69, 0]; // Tebal mati
    const textDouble = [29, 33, 17]; // Ukuran teks 2x
    const textNormal = [29, 33, 0]; // Ukuran teks normal
    const lineFeed = [10]; // Newline

    // 1. Inisialisasi
    bytes.addAll(escInit);

    // 2. Header Toko
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    bytes.addAll(textDouble);
    bytes.addAll(utf8.encode('$storeName\n'));
    bytes.addAll(textNormal);
    bytes.addAll(boldOff);
    bytes.addAll(utf8.encode('Self-Order & Digital Menu\n'));
    bytes.addAll(utf8.encode('================================\n'));

    if (tableNumber != null && tableNumber.isNotEmpty) {
      bytes.addAll(boldOn);
      bytes.addAll(utf8.encode('MEJA / ANTREAN: $tableNumber\n'));
      bytes.addAll(boldOff);
      bytes.addAll(utf8.encode('--------------------------------\n'));
    }

    bytes.addAll(utf8.encode('SCAN QR DI BAWAH INI\nUNTUK PESAN & BAYAR\n\n'));

    // 3. Perintah ESC/POS QR Code standar
    final urlBytes = utf8.encode(qrUrl);
    final len = urlBytes.length + 3;
    final pL = len % 256;
    final pH = len ~/ 256;

    // Set model QR (Model 2)
    bytes.addAll([29, 40, 107, 4, 0, 49, 65, 50, 0]);
    // Set dot size (size 8 untuk hasil cetak jelas di 58mm)
    bytes.addAll([29, 40, 107, 3, 0, 49, 67, 8]);
    // Set error correction level M (49)
    bytes.addAll([29, 40, 107, 3, 0, 49, 69, 49]);
    // Store data QR
    bytes.addAll([29, 40, 107, pL, pH, 49, 80, 48, ...urlBytes]);
    // Print QR symbol
    bytes.addAll([29, 40, 107, 3, 0, 49, 81, 48]);

    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);

    // 4. Footer Petunjuk
    bytes.addAll(alignCenter);
    bytes.addAll(utf8.encode('Buka kamera ponsel Anda & scan QR\n'));
    bytes.addAll(utf8.encode('Pilih Menu, Bayar, dan Santai!\n'));
    bytes.addAll(utf8.encode('================================\n'));
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);

    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}
