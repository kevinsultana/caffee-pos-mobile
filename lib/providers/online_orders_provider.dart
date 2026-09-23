import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import 'auth_provider.dart';

@immutable
class OnlineOrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;

  const OnlineOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  int get pendingCount => orders.length;

  OnlineOrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? Function()? error,
  }) {
    return OnlineOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}

class OnlineOrdersNotifier extends Notifier<OnlineOrdersState> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  OnlineOrdersState build() {
    return const OnlineOrdersState();
  }

  /// Ambil daftar pesanan QR online yang masih menunggu pembayaran (PENDING_PAYMENT)
  Future<void> fetchPendingOrders() async {
    final authState = ref.read(authProvider);
    final storeId = authState.storeId;

    if (storeId.isEmpty) {
      state = state.copyWith(isLoading: false, orders: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final List<dynamic> response = await _client
          .from('Order')
          .select('*, items:OrderItem(*)')
          .eq('storeId', storeId)
          .eq('source', 'PUBLIC_QR')
          .eq('status', 'PENDING_PAYMENT')
          .gt('expiresAt', nowUtc)
          .order('createdAt', ascending: false);

      final List<OrderModel> loadedOrders = response
          .whereType<Map<String, dynamic>>()
          .map((item) => OrderModel.fromMap(item))
          .toList();

      state = state.copyWith(
        orders: loadedOrders,
        isLoading: false,
        error: () => null,
      );
    } catch (e) {
      debugPrint('[OnlineOrdersNotifier] Error fetching pending orders: $e');
      state = state.copyWith(
        isLoading: false,
        error: () => 'Gagal memuat pesanan online: ${e.toString()}',
      );
    }
  }

  /// Batalkan dan hapus pesanan QR online
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _client.from('Order').delete().eq('id', orderId);

      // Perbarui state lokal
      final updatedList = state.orders.where((o) => o.id != orderId).toList();
      state = state.copyWith(orders: updatedList);
      return true;
    } catch (e) {
      debugPrint('[OnlineOrdersNotifier] Error canceling order: $e');
      return false;
    }
  }
}

final onlineOrdersProvider =
    NotifierProvider<OnlineOrdersNotifier, OnlineOrdersState>(OnlineOrdersNotifier.new);
