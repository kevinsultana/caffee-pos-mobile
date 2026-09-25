import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/phone_utils.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import 'customer_provider.dart';
import 'promotion_provider.dart';

@immutable
class CartState {
  final List<CartItemModel> items;
  final DiningOption diningOption;
  final String customerName;
  final String? customerId;
  final String? customerPhone;
  final String? unregisteredQrPhone;
  final String? tableNumber;
  final String queueInput; // Angka antrean yang diinput kasir
  final String? activeQrOrderId;
  final String? activeQrToken;
  final PromotionModel? appliedPromo;

  const CartState({
    this.items = const [],
    this.diningOption = DiningOption.dineIn,
    this.customerName = '',
    this.customerId,
    this.customerPhone,
    this.unregisteredQrPhone,
    this.tableNumber,
    this.queueInput = '',
    this.activeQrOrderId,
    this.activeQrToken,
    this.appliedPromo,
  });

  String get fullQueueNumber {
    if (queueInput.trim().isEmpty) return '';
    return '${diningOption.shortCode}-${queueInput.trim().padLeft(3, '0')}';
  }

  bool get hasActiveQrOrder => activeQrOrderId != null && activeQrOrderId!.isNotEmpty;

  bool get isMemberVerified => customerId != null && customerId!.isNotEmpty;

  bool get isQrOrderWithoutPhone =>
      hasActiveQrOrder && !isMemberVerified && (customerPhone == null || customerPhone!.trim().isEmpty);

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get subtotal => totalPrice;

  /// Hitung potongan diskon dari promosi yang terpasang
  double get promotionDiscount {
    if (appliedPromo == null || isEmpty) return 0.0;
    final eval = PromotionNotifier.evaluatePromo(appliedPromo!, this);
    return eval.isEligible ? eval.estimatedDiscount : 0.0;
  }

  /// Total akhir setelah dikurangi diskon promosi
  double get grandTotal {
    final net = totalPrice - promotionDiscount;
    return math.max(0.0, net);
  }

  bool get hasAppliedPromo => appliedPromo != null && promotionDiscount > 0;
  bool get hasPromoApplied => appliedPromo != null;

  String get formattedTotalPrice {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalPrice);
  }

  String get formattedSubtotal => formattedTotalPrice;

  String get formattedPromotionDiscount {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(promotionDiscount);
  }

  String get formattedGrandTotal {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(grandTotal);
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItemModel>? items,
    DiningOption? diningOption,
    String? customerName,
    String? Function()? customerId,
    String? Function()? customerPhone,
    String? Function()? unregisteredQrPhone,
    String? Function()? tableNumber,
    String? queueInput,
    String? Function()? activeQrOrderId,
    String? Function()? activeQrToken,
    PromotionModel? Function()? appliedPromo,
  }) {
    return CartState(
      items: items ?? this.items,
      diningOption: diningOption ?? this.diningOption,
      customerName: customerName ?? this.customerName,
      customerId: customerId != null ? customerId() : this.customerId,
      customerPhone: customerPhone != null ? customerPhone() : this.customerPhone,
      unregisteredQrPhone: unregisteredQrPhone != null ? unregisteredQrPhone() : this.unregisteredQrPhone,
      tableNumber: tableNumber != null ? tableNumber() : this.tableNumber,
      queueInput: queueInput ?? this.queueInput,
      activeQrOrderId: activeQrOrderId != null ? activeQrOrderId() : this.activeQrOrderId,
      activeQrToken: activeQrToken != null ? activeQrToken() : this.activeQrToken,
      appliedPromo: appliedPromo != null ? appliedPromo() : this.appliedPromo,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState();
  }

  /// Tambah item ke keranjang
  void addToCart({
    required ProductModel product,
    ProductVariantModel? variant,
    int quantity = 1,
    String? notes,
  }) {
    if (quantity <= 0) return;

    final cleanNotes = notes?.trim().isEmpty == true ? null : notes?.trim();
    final effectivePrice = (variant != null && variant.price > 0)
        ? variant.price
        : product.price;

    // ID Komposit unik berdasarkan Produk, Varian, dan Catatan
    final compositeId = '${product.id}-${variant?.id ?? "def"}-${cleanNotes ?? ""}';

    final existingIndex = state.items.indexWhere((item) => item.id == compositeId);

    if (existingIndex != -1) {
      // Item sudah ada dengan opsi & catatan yang sama, tambahkan kuantitasnya
      final updatedList = List<CartItemModel>.from(state.items);
      final currentItem = updatedList[existingIndex];
      updatedList[existingIndex] = currentItem.copyWith(
        quantity: currentItem.quantity + quantity,
      );
      state = state.copyWith(items: updatedList);
    } else {
      // Tambahkan item baru ke dalam keranjang
      final newItem = CartItemModel(
        id: compositeId,
        productId: product.id,
        productName: product.name,
        productImageUrl: product.imageUrl,
        variantId: variant?.id,
        variantName: variant?.name,
        unitPrice: effectivePrice,
        quantity: quantity,
        notes: cleanNotes,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }

    _revalidatePromo();
  }

  /// Tambah kuantitas item (+1)
  void incrementQuantity(String itemId) {
    final updatedList = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: item.quantity + 1);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedList);
    _revalidatePromo();
  }

  /// Kurangi kuantitas item (-1), jika 0 maka hapus item
  void decrementQuantity(String itemId) {
    final existingItem = state.items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => const CartItemModel(
        id: '',
        productId: '',
        productName: '',
        unitPrice: 0,
        quantity: 0,
      ),
    );

    if (existingItem.id.isEmpty) return;

    if (existingItem.quantity > 1) {
      final updatedList = state.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(quantity: item.quantity - 1);
        }
        return item;
      }).toList();
      state = state.copyWith(items: updatedList);
    } else {
      removeItem(itemId);
    }

    _revalidatePromo();
  }

  /// Hapus item tertentu dari keranjang
  void removeItem(String itemId) {
    final updatedList = state.items.where((item) => item.id != itemId).toList();
    state = state.copyWith(items: updatedList);
    _revalidatePromo();
  }

  /// Update catatan (notes) item yang sudah ada di keranjang
  void updateItemNotes(String itemId, String? notes) {
    final cleanNotes = notes?.trim().isEmpty == true ? null : notes?.trim();
    final itemIndex = state.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final currentItem = state.items[itemIndex];
    if ((currentItem.notes?.trim() ?? '') == (cleanNotes ?? '')) return;

    // ID Komposit baru berdasarkan Produk, Varian, dan Catatan baru
    final newCompositeId = '${currentItem.productId}-${currentItem.variantId ?? "def"}-${cleanNotes ?? ""}';

    // Cek apakah item lain dengan kombinasi ini sudah ada di keranjang
    final otherItemIndex = state.items.indexWhere(
      (item) => item.id == newCompositeId && item.id != itemId,
    );

    if (otherItemIndex != -1) {
      // Gabungkan kuantitas item yang diedit ke item yang sudah ada
      final targetItem = state.items[otherItemIndex];
      final mergedQuantity = targetItem.quantity + currentItem.quantity;
      final mergedItem = targetItem.copyWith(quantity: mergedQuantity);

      final resultList = <CartItemModel>[];
      for (final item in state.items) {
        if (item.id == itemId) {
          continue;
        } else if (item.id == newCompositeId) {
          resultList.add(mergedItem);
        } else {
          resultList.add(item);
        }
      }
      state = state.copyWith(items: resultList);
    } else {
      // Perbarui catatan dan composite ID pada item yang bersangkutan
      final updatedList = List<CartItemModel>.from(state.items);
      updatedList[itemIndex] = CartItemModel(
        id: newCompositeId,
        productId: currentItem.productId,
        productName: currentItem.productName,
        productImageUrl: currentItem.productImageUrl,
        variantId: currentItem.variantId,
        variantName: currentItem.variantName,
        unitPrice: currentItem.unitPrice,
        quantity: currentItem.quantity,
        notes: cleanNotes,
      );
      state = state.copyWith(items: updatedList);
    }
  }

  /// Terapkan promo ke keranjang
  void applyPromo(PromotionModel promo) {
    state = state.copyWith(appliedPromo: () => promo);
  }

  /// Hapus promo dari keranjang
  void removePromo() {
    state = state.copyWith(appliedPromo: () => null);
  }

  /// Validasi ulang promo saat isi keranjang berubah
  void _revalidatePromo() {
    if (state.appliedPromo != null) {
      final eval = PromotionNotifier.evaluatePromo(state.appliedPromo!, state);
      if (!eval.isEligible) {
        state = state.copyWith(appliedPromo: () => null);
      }
    }
  }

  /// Ganti opsi makan (Dine-in vs Takeaway)
  void setDiningOption(DiningOption option) {
    state = state.copyWith(diningOption: option);
  }

  /// Update nama pelanggan
  void setCustomerName(String name) {
    state = state.copyWith(customerName: name);
  }

  /// Pilih member / guest
  void setCustomer(CustomerModel? customer) {
    if (customer != null) {
      state = state.copyWith(
        customerId: () => customer.id,
        customerName: customer.name,
        customerPhone: () => customer.phone,
        unregisteredQrPhone: () => null,
      );
    } else {
      state = state.copyWith(
        customerId: () => null,
        customerName: state.customerName.isEmpty ? 'Pelanggan' : state.customerName,
        customerPhone: () => null,
      );
    }
  }

  /// Update ID member
  void setCustomerId(String? id) {
    state = state.copyWith(customerId: () => id);
  }

  /// Update nomor telepon pelanggan
  void setCustomerPhone(String? phone) {
    state = state.copyWith(customerPhone: () => phone);
  }

  /// Update nomor telepon QR yang belum terdaftar
  void setUnregisteredQrPhone(String? phone) {
    state = state.copyWith(unregisteredQrPhone: () => phone);
  }

  /// Update nomor meja
  void setTableNumber(String? table) {
    state = state.copyWith(tableNumber: () => table);
  }

  /// Update input digit nomor antrean (hanya angka)
  void setQueueInput(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(queueInput: cleaned);
  }

  /// Muat pesanan QR Online ke dalam keranjang & identifikasi member secara otomatis
  Future<void> loadQrOrder({
    required OrderModel order,
    required List<ProductModel> catalogProducts,
  }) async {
    final List<CartItemModel> mappedItems = [];
    for (final it in order.items) {
      final cleanNotes = it.notes?.trim().isEmpty == true ? null : it.notes?.trim();
      final compositeId = '${it.productId}-${it.variantId ?? "def"}-${cleanNotes ?? ""}';

      // Cari thumbnail gambar produk jika cocok
      String? imageUrl;
      final matches = catalogProducts.where((p) => p.id == it.productId);
      if (matches.isNotEmpty) {
        imageUrl = matches.first.imageUrl;
      }

      mappedItems.add(CartItemModel(
        id: compositeId,
        productId: it.productId,
        productName: it.productNameSnapshot,
        productImageUrl: imageUrl,
        variantId: it.variantId,
        variantName: null,
        unitPrice: it.unitPrice,
        quantity: it.quantity,
        notes: cleanNotes,
      ));
    }

    // Ambil angka antrean jika ada di QR order
    String qDigits = '';
    DiningOption option = DiningOption.dineIn;
    if (order.queueNumber != null && order.queueNumber!.isNotEmpty) {
      qDigits = order.queueNumber!.replaceAll(RegExp(r'\D'), '');
      if (order.queueNumber!.toUpperCase().startsWith('TA') ||
          order.queueNumber!.toUpperCase().startsWith('T')) {
        option = DiningOption.takeaway;
      } else {
        option = DiningOption.dineIn;
      }
    }

    // Identifikasi Pelanggan / Member dari nomor telepon QR order
    final rawName = order.customerNameSnapshot.trim().isNotEmpty
        ? order.customerNameSnapshot.trim()
        : 'Pelanggan';
    final rawPhone = order.customerPhoneSnapshot?.trim() ?? '';
    final normPhone = normalizePhone(rawPhone);

    String? matchedCustomerId;
    String finalCustomerName = rawName;
    String? finalCustomerPhone = normPhone ?? (rawPhone.isNotEmpty ? rawPhone : null);
    String? finalUnregisteredQrPhone;

    if (normPhone != null && normPhone.isNotEmpty) {
      final customerNotifier = ref.read(customerProvider.notifier);
      final matched = await customerNotifier.findCustomerByPhone(normPhone);

      if (matched != null) {
        // Kondisi 1: Sudah Terdaftar sebagai Member
        matchedCustomerId = matched.id;
        finalCustomerName = matched.name;
        finalCustomerPhone = matched.phone ?? normPhone;
        finalUnregisteredQrPhone = null;
      } else {
        // Kondisi 2: Belum Terdaftar (Tawarkan pendaftaran)
        matchedCustomerId = null;
        finalCustomerName = rawName;
        finalCustomerPhone = normPhone;
        finalUnregisteredQrPhone = normPhone;
      }
    } else {
      matchedCustomerId = null;
      finalCustomerName = rawName;
      finalCustomerPhone = null;
      finalUnregisteredQrPhone = null;
    }

    state = state.copyWith(
      items: mappedItems,
      customerName: finalCustomerName,
      customerId: () => matchedCustomerId,
      customerPhone: () => finalCustomerPhone,
      unregisteredQrPhone: () => finalUnregisteredQrPhone,
      diningOption: option,
      queueInput: qDigits,
      activeQrOrderId: () => order.id,
      activeQrToken: () => order.publicQrToken ?? order.orderNumber,
    );

    _revalidatePromo();
  }

  /// Lepas tautan pesanan QR dan jadikan transaksi kasir biasa
  void detachQrOrder() {
    state = state.copyWith(
      activeQrOrderId: () => null,
      activeQrToken: () => null,
      unregisteredQrPhone: () => null,
    );
  }

  /// Kosongkan seluruh keranjang
  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
