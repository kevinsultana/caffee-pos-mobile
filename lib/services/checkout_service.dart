import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/uuid_generator.dart';
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

  /// Eksekusi checkout transaksi POS ke tabel Order, OrderItem, Payment, dan OrderPromotion
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

    if (shiftId.trim().isEmpty) {
      return const CheckoutResult(
        error: 'Sesi Shift Kasir belum dibuka! Buka shift terlebih dahulu di tab Kelola Shift.',
      );
    }

    if (dbUserId.trim().isEmpty) {
      return const CheckoutResult(
        error: 'Sesi Kasir tidak valid (User ID kosong). Silakan login ulang.',
      );
    }

    if (storeId.trim().isEmpty) {
      return const CheckoutResult(
        error: 'Data Toko kasir tidak ditemukan. Silakan login kembali.',
      );
    }

    final productSubtotal = cart.subtotal;
    final promotionDiscount = cart.promotionDiscount;
    final grandTotal = cart.grandTotal;

    if (productSubtotal.isNaN || productSubtotal <= 0) {
      return const CheckoutResult(
        error: 'Total transaksi tidak valid (harus lebih besar dari Rp 0).',
      );
    }

    for (final item in cart.items) {
      if (item.quantity <= 0) {
        return CheckoutResult(
          error: 'Kuantitas untuk "${item.productName}" tidak valid (harus lebih dari 0).',
        );
      }
      if (item.unitPrice < 0 || item.subtotal < 0) {
        return CheckoutResult(
          error: 'Harga untuk "${item.productName}" tidak valid.',
        );
      }
    }

    if (paymentMethod == 'CASH') {
      if (cashReceived == null || cashReceived.isNaN || cashReceived < grandTotal) {
        return const CheckoutResult(
          error: 'Uang tunai yang diterima kurang dari total belanja.',
        );
      }
    }

    try {
      final now = DateTime.now();
      final nowUtc = now.toUtc().toIso8601String();
      
      // Ambil nomor antrean dari cart jika sudah diisi kasir, atau generate otomatis sebagai fallback
      final queueNumber = cart.fullQueueNumber.isNotEmpty
          ? cart.fullQueueNumber
          : await generateQueueNumber(
              client: client,
              storeId: storeId,
              option: cart.diningOption,
            );

      final changeAmount = paymentMethod == 'CASH'
          ? (cashReceived! - grandTotal)
          : null;

      final custName = (customerName?.trim().isNotEmpty ?? false)
          ? customerName!.trim()
          : (cart.customerName.trim().isNotEmpty ? cart.customerName.trim() : 'Pelanggan');

      late final String orderId;
      late final String effectiveOrderNumber;
      String? publicToken;

      // ── 1. INSERT / UPDATE KE TABEL Order ───────────────────────────────────
      if (cart.activeQrOrderId != null && cart.activeQrOrderId!.isNotEmpty) {
        // Tautkan & perbarui pesanan QR online yang sudah ada
        orderId = cart.activeQrOrderId!;
        final orderUpdateData = {
          'createdById': dbUserId.isNotEmpty ? dbUserId : null,
          'queueNumber': queueNumber,
          'status': 'PAID',
          'customerId': cart.customerId,
          'customerNameSnapshot': custName,
          'customerPhoneSnapshot': cart.customerPhone,
          'productSubtotal': productSubtotal,
          'promotionDiscount': promotionDiscount,
          'taxableSubtotal': grandTotal,
          'grandTotal': grandTotal,
          'roundingAmount': 0,
          'cashPayable': grandTotal,
          'paidAt': nowUtc,
          'updatedAt': nowUtc,
        };

        final orderRes = await client.from('Order').update(orderUpdateData).eq('id', orderId).select().single();
        effectiveOrderNumber = orderRes['orderNumber']?.toString() ?? generateOrderNumber();
        publicToken = orderRes['publicQrToken']?.toString();

        // Hapus item pesanan QR lama sebelum menginsert item keranjang kasir terbaru
        await client.from('OrderItem').delete().eq('orderId', orderId);
      } else {
        // Buat pesanan baru langsung dari kasir POS
        effectiveOrderNumber = generateOrderNumber();
        final newOrderId = UuidGenerator.v4();
        final orderInsertData = {
          'id': newOrderId,
          'storeId': storeId,
          'createdById': dbUserId.isNotEmpty ? dbUserId : null,
          'orderNumber': effectiveOrderNumber,
          'queueNumber': queueNumber,
          'source': 'POS',
          'status': 'PAID',
          'customerId': cart.customerId,
          'customerNameSnapshot': custName,
          'customerPhoneSnapshot': cart.customerPhone,
          'productSubtotal': productSubtotal,
          'promotionDiscount': promotionDiscount,
          'taxableSubtotal': grandTotal,
          'serviceChargeRate': 0,
          'serviceChargeAmount': 0,
          'taxRate': 0,
          'taxBase': 0,
          'taxAmount': 0,
          'grandTotal': grandTotal,
          'roundingAmount': 0,
          'cashPayable': grandTotal,
          'paidAt': nowUtc,
          'updatedAt': nowUtc,
        };

        final orderRes = await client.from('Order').insert(orderInsertData).select().single();
        orderId = orderRes['id'].toString();
      }

      // ── 2. INSERT KE TABEL OrderPromotion (jika promo aktif) ───────────────
      if (cart.appliedPromo != null && promotionDiscount > 0) {
        final promo = cart.appliedPromo!;
        try {
          await client.from('OrderPromotion').insert({
            'id': UuidGenerator.v4(),
            'orderId': orderId,
            'promotionId': promo.id,
            'sequenceNo': 1,
            'promotionNameSnapshot': promo.name,
            'promotionCodeSnapshot': promo.code,
            'discountTypeSnapshot': promo.discountType,
            'discountScopeSnapshot': promo.discountScope,
            'valueSnapshot': promo.discountValue,
            'maxDiscountSnapshot': promo.maxDiscount,
            'discountAmount': promotionDiscount,
          });

          // Tambah penggunaan kuota promo
          await client.from('Promotion').update({
            'usageCount': promo.usageCount + 1,
          }).eq('id', promo.id);
        } catch (e) {
          debugPrint('Catatan: Gagal menyimpan OrderPromotion / increment usage: $e');
        }
      }

      // ── 3. INSERT KE TABEL OrderItem ──────────────────────────────────────
      final List<Map<String, dynamic>> orderItemsInsert = cart.items.map((it) {
        final displayName = it.variantName != null
            ? '${it.productName} (${it.variantName})'
            : it.productName;

        return {
          'id': UuidGenerator.v4(),
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

      // ── 4. INSERT KE TABEL Payment ────────────────────────────────────────
      final paymentInsertData = {
        'id': UuidGenerator.v4(),
        'orderId': orderId,
        'shiftId': shiftId,
        'method': paymentMethod,
        'status': 'PAID',
        'amount': grandTotal,
        'cashReceived': paymentMethod == 'CASH' ? cashReceived : null,
        'changeAmount': changeAmount,
        'paidAt': nowUtc,
        'updatedAt': nowUtc,
      };

      final paymentRes = await client.from('Payment').insert(paymentInsertData).select().single();

      // Susun objek OrderModel lengkap untuk keperluan cetak struk
      final fullOrder = OrderModel(
        id: orderId,
        storeId: storeId,
        createdById: dbUserId,
        orderNumber: effectiveOrderNumber,
        queueNumber: queueNumber,
        source: cart.hasActiveQrOrder ? 'PUBLIC_QR' : 'POS',
        status: 'PAID',
        publicQrToken: publicToken,
        customerId: cart.customerId,
        customerNameSnapshot: custName,
        customerPhoneSnapshot: cart.customerPhone,
        productSubtotal: productSubtotal,
        promotionDiscount: promotionDiscount,
        promoCodeSnapshot: cart.appliedPromo?.code,
        taxableSubtotal: grandTotal,
        grandTotal: grandTotal,
        cashPayable: grandTotal,
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
