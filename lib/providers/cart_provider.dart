import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cart_item_model.dart';
import '../models/product_model.dart';

@immutable
class CartState {
  final List<CartItemModel> items;
  final DiningOption diningOption;
  final String customerName;
  final String? tableNumber;

  const CartState({
    this.items = const [],
    this.diningOption = DiningOption.dineIn,
    this.customerName = '',
    this.tableNumber,
  });

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
  }) {
    return CartState(
      items: items ?? this.items,
      diningOption: diningOption ?? this.diningOption,
      customerName: customerName ?? this.customerName,
      tableNumber: tableNumber != null ? tableNumber() : this.tableNumber,
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

  /// Kosongkan seluruh keranjang
  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
