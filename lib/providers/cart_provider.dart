import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

@immutable
class CartState {
  final List<CartItemModel> items;
  final DiningOption diningOption;
  final String customerName;
  final String? tableNumber;
  final String queueInput; // Angka antrean yang diinput kasir
  final String? activeQrOrderId;
  final String? activeQrToken;

  const CartState({
    this.items = const [],
    this.diningOption = DiningOption.dineIn,
    this.customerName = '',
    this.tableNumber,
    this.queueInput = '',
    this.activeQrOrderId,
    this.activeQrToken,
  });

  String get fullQueueNumber {
    if (queueInput.trim().isEmpty) return '';
    return '${diningOption.shortCode}-${queueInput.trim().padLeft(3, '0')}';
  }

  bool get hasActiveQrOrder => activeQrOrderId != null && activeQrOrderId!.isNotEmpty;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get formattedTotalPrice {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalPrice);
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItemModel>? items,
    DiningOption? diningOption,
    String? customerName,
    String? Function()? tableNumber,
    String? queueInput,
    String? Function()? activeQrOrderId,
    String? Function()? activeQrToken,
  }) {
    return CartState(
      items: items ?? this.items,
      diningOption: diningOption ?? this.diningOption,
      customerName: customerName ?? this.customerName,
      tableNumber: tableNumber != null ? tableNumber() : this.tableNumber,
      queueInput: queueInput ?? this.queueInput,
      activeQrOrderId: activeQrOrderId != null ? activeQrOrderId() : this.activeQrOrderId,
      activeQrToken: activeQrToken != null ? activeQrToken() : this.activeQrToken,
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
  }

  /// Hapus item tertentu dari keranjang
  void removeItem(String itemId) {
    final updatedList = state.items.where((item) => item.id != itemId).toList();
    state = state.copyWith(items: updatedList);
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
          // Lewatkan item lama yang digabungkan
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

  /// Ganti opsi makan (Dine-in vs Takeaway)
  void setDiningOption(DiningOption option) {
    state = state.copyWith(diningOption: option);
  }

  /// Update nama pelanggan
  void setCustomerName(String name) {
    state = state.copyWith(customerName: name);
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

  /// Muat pesanan QR Online ke dalam keranjang
  void loadQrOrder({
    required OrderModel order,
    required List<ProductModel> catalogProducts,
  }) {
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
      if (order.queueNumber!.toUpperCase().startsWith('TA')) {
        option = DiningOption.takeaway;
      } else {
        option = DiningOption.dineIn;
      }
    }

    state = state.copyWith(
      items: mappedItems,
      customerName: order.customerNameSnapshot.trim().isNotEmpty
          ? order.customerNameSnapshot.trim()
          : 'Pelanggan',
      diningOption: option,
      queueInput: qDigits,
      activeQrOrderId: () => order.id,
      activeQrToken: () => order.publicQrToken ?? order.orderNumber,
    );
  }

  /// Lepas tautan pesanan QR dan jadikan transaksi kasir biasa
  void detachQrOrder() {
    state = state.copyWith(
      activeQrOrderId: () => null,
      activeQrToken: () => null,
    );
  }

  /// Kosongkan seluruh keranjang
  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
