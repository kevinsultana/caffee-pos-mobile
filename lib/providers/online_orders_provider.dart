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

  /// Singleton channel — hanya satu instance aktif per session untuk mencegah double-subscribe
  RealtimeChannel? _channel;

  @override
  OnlineOrdersState build() {
    // Aktifkan realtime listener saat provider dibuat
    Future.microtask(() => _subscribeToRealtime());

    // Bersihkan channel dengan tuntas saat provider di-dispose
    ref.onDispose(_unsubscribeFromRealtime);

    return const OnlineOrdersState();
  }

  // ─────────────────────────────────────────────
  // SUPABASE REALTIME LISTENER
  // ─────────────────────────────────────────────

  /// Aktifkan realtime listener ke tabel Order untuk pesanan QR yang masuk.
  /// Menggunakan pola singleton: jika channel sudah ada, tidak buat ulang.
  void _subscribeToRealtime() {
    final authState = ref.read(authProvider);
    final storeId = authState.storeId;

    if (storeId.isEmpty) {
      debugPrint('[OnlineOrdersNotifier] storeId kosong, skip Realtime subscribe.');
      return;
    }

    // Guard singleton: jika channel sudah aktif, tidak buat channel baru
    if (_channel != null) {
      debugPrint('[OnlineOrdersNotifier] Realtime channel sudah aktif, skip duplicate subscribe.');
      return;
    }

    // Nama channel unik per store untuk menghindari konflik multi-user
    final channelName = 'online-orders-$storeId';

    debugPrint('[OnlineOrdersNotifier] Subscribe Realtime channel: $channelName');

    _channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Order',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'storeId',
            value: storeId,
          ),
          callback: (payload) {
            debugPrint('[OnlineOrdersNotifier] Realtime INSERT event: ${payload.newRecord}');
            _handleRealtimeEvent(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Order',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'storeId',
            value: storeId,
          ),
          callback: (payload) {
            debugPrint('[OnlineOrdersNotifier] Realtime UPDATE event: ${payload.newRecord}');
            _handleRealtimeEvent(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[OnlineOrdersNotifier] Realtime subscription error: $error');
          } else {
            debugPrint('[OnlineOrdersNotifier] Realtime status: $status');
          }
          // Saat pertama subscribe berhasil, langsung fetch data terbaru
          if (status == RealtimeSubscribeStatus.subscribed) {
            fetchPendingOrders();
          }
        });
  }

  /// Batalkan channel Realtime dan bersihkan referensi.
  /// Dipanggil dari ref.onDispose untuk memastikan tidak ada memory leak.
  void _unsubscribeFromRealtime() {
    if (_channel != null) {
      debugPrint('[OnlineOrdersNotifier] Unsubscribe Realtime channel.');
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }

  /// Tangani event Realtime dari Supabase.
  /// Hanya refresh list jika event merupakan pesanan QR yang relevan (PENDING_PAYMENT).
  void _handleRealtimeEvent(Map<String, dynamic> record) {
    final source = record['source']?.toString();
    final status = record['status']?.toString();

    // Filter di sisi client: hanya proses pesanan QR yang masih pending
    final isQrOrder = source == 'PUBLIC_QR';
    final isPending = status == 'PENDING_PAYMENT';

    if (isQrOrder && isPending) {
      // Refresh penuh dari Supabase agar data item juga lengkap (JOIN diperlukan)
      fetchPendingOrders();
    } else if (!isPending) {
      // Jika status berubah (misal: PAID atau CANCELLED), hapus dari list lokal
      final orderId = record['id']?.toString();
      if (orderId != null) {
        final updated = state.orders.where((o) => o.id != orderId).toList();
        if (updated.length != state.orders.length) {
          state = state.copyWith(orders: updated);
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // FETCH MANUAL (Pull-to-refresh & inisialisasi)
  // ─────────────────────────────────────────────

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
