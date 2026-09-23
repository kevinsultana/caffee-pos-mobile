import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';

class CheckoutResult {
  final OrderModel? order;
  final String? error;

  const CheckoutResult({this.order, this.error});

  bool get isSuccess => order != null && error == null;
}

class CheckoutService {
  /// Generate nomor pesanan dengan format ORD-YYMMDD-XXXX (sesuai standar POS Web)
  static String generateOrderNumber() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final rand = 1000 + Random().nextInt(9000);
    return 'ORD-$yy$mm$dd-$rand';
  }

  /// Generate nomor antrean berdasarkan opsi layanan: A-XXX untuk Dine-in, TA-XXX untuk Takeaway
  static Future<String> generateQueueNumber({
    required SupabaseClient client,
    required String storeId,
    required DiningOption option,
  }) async {
    final prefix = option.shortCode;
    try {
      final todayStart = DateTime.now();
      final startOfDay = DateTime(todayStart.year, todayStart.month, todayStart.day).toIso8601String();

      // Hitung order hari ini dengan prefix yang sama
      final response = await client
          .from('Order')
          .select('id')
          .eq('storeId', storeId)
          .gte('createdAt', startOfDay)
          .like('queueNumber', '$prefix-%');

      final count = (response as List).length + 1;
      return '$prefix-${count.toString().padLeft(3, '0')}';
    } catch (_) {
      final rand = 1 + Random().nextInt(99);
      return '$prefix-${rand.toString().padLeft(3, '0')}';
    }
  }

  /// Eksekusi checkout transaksi POS ke tabel Order, OrderItem, dan Payment
  static Future<CheckoutResult> processCheckout({
    required SupabaseClient client,
    required CartState cart,
    required String storeId,
    required String dbUserId,
    required String shiftId,
    required String paymentMethod, // 'CASH' | 'QRIS'
    double? cashReceived,
    String? customerName,
  }) async {
    if (cart.isEmpty) {
      return const CheckoutResult(error: 'Keranjang belanja masih kosong.');
    }

    if (shiftId.isEmpty) {
      return const CheckoutResult(
        error: 'Sesi Shift Kasir belum dibuka! Buka shift terlebih dahulu di tab Kelola Shift.',
      );
    }

    if (storeId.isEmpty) {
      return const CheckoutResult(
        error: 'Data Toko kasir tidak ditemukan. Silakan login kembali.',
      );
    }

    final totalAmount = cart.totalPrice;

    if (paymentMethod == 'CASH') {
      if (cashReceived == null || cashReceived < totalAmount) {
        return const CheckoutResult(
          error: 'Uang tunai yang diterima kurang dari total belanja.',
        );
      }
    }

    try {
      final now = DateTime.now();
      final orderNumber = generateOrderNumber();
      final queueNumber = await generateQueueNumber(
        client: client,
        storeId: storeId,
        option: cart.diningOption,
      );

      final changeAmount = paymentMethod == 'CASH'
          ? (cashReceived! - totalAmount)
          : null;

      final custName = (customerName?.trim().isNotEmpty ?? false)
          ? customerName!.trim()
          : (cart.customerName.trim().isNotEmpty ? cart.customerName.trim() : 'Pelanggan');

      // ── 1. INSERT KE TABEL Order ──────────────────────────────────────────
      final orderInsertData = {
        'storeId': storeId,
        'createdById': dbUserId.isNotEmpty ? dbUserId : null,
        'orderNumber': orderNumber,
        'queueNumber': queueNumber,
        'source': 'POS',
        'status': 'PAID',
        'customerNameSnapshot': custName,
        'productSubtotal': totalAmount,
        'promotionDiscount': 0,
        'taxableSubtotal': totalAmount,
        'serviceChargeRate': 0,
        'serviceChargeAmount': 0,
        'taxRate': 0,
        'taxBase': 0,
        'taxAmount': 0,
        'grandTotal': totalAmount,
        'roundingAmount': 0,
        'cashPayable': totalAmount,
        'paidAt': now.toIso8601String(),
      };

      final orderRes = await client.from('Order').insert(orderInsertData).select().single();
      final orderId = orderRes['id'].toString();

      // ── 2. INSERT KE TABEL OrderItem ──────────────────────────────────────
      final List<Map<String, dynamic>> orderItemsInsert = cart.items.map((it) {
        final displayName = it.variantName != null
            ? '${it.productName} (${it.variantName})'
            : it.productName;

        return {
          'orderId': orderId,
          'productId': it.productId,
          'variantId': it.variantId,
          'productNameSnapshot': displayName,
          'quantity': it.quantity,
          'unitPrice': it.unitPrice,
          'promotionDiscount': 0,
          'subtotal': it.subtotal,
          'hppUnit': 0,
          'hppTotal': 0,
          'notes': it.notes,
        };
      }).toList();

      final itemsRes = await client.from('OrderItem').insert(orderItemsInsert).select();

      // ── 3. INSERT KE TABEL Payment ────────────────────────────────────────
      final paymentInsertData = {
        'orderId': orderId,
        'shiftId': shiftId,
        'method': paymentMethod,
        'status': 'PAID',
        'amount': totalAmount,
        'cashReceived': paymentMethod == 'CASH' ? cashReceived : null,
        'changeAmount': changeAmount,
        'paidAt': now.toIso8601String(),
      };

      final paymentRes = await client.from('Payment').insert(paymentInsertData).select().single();

      // Susun objek OrderModel lengkap untuk keperluan cetak struk
      final fullOrder = OrderModel(
        id: orderId,
        storeId: storeId,
        createdById: dbUserId,
        orderNumber: orderNumber,
        queueNumber: queueNumber,
        source: 'POS',
        status: 'PAID',
        customerNameSnapshot: custName,
        productSubtotal: totalAmount,
        taxableSubtotal: totalAmount,
        grandTotal: totalAmount,
        cashPayable: totalAmount,
        paidAt: now,
        createdAt: now,
        items: (itemsRes as List).map((i) => OrderItemModel.fromMap(i as Map<String, dynamic>)).toList(),
        payment: PaymentModel.fromMap(paymentRes),
      );

      return CheckoutResult(order: fullOrder);
    } catch (e) {
      return CheckoutResult(error: 'Gagal memproses transaksi: ${e.toString()}');
    }
  }
}
