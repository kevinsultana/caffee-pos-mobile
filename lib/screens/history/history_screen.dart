import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/store_settings_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _filterTodayOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeShift = ref.read(shiftProvider).activeShift;
      if (activeShift == null) {
        if (mounted) {
          setState(() {
            _orders = [];
            _isLoading = false;
          });
        }
        return;
      }

      final auth = ref.read(authProvider);
      final storeId = auth.storeId;
      final supaClient = Supabase.instance.client;

      var query = supaClient.from('Order').select('''
        id, storeId, createdById, orderNumber, queueNumber, source, status,
        customerNameSnapshot, customerPhoneSnapshot, productSubtotal,
        promotionDiscount, taxableSubtotal, grandTotal, cashPayable, paidAt, createdAt,
        items:OrderItem(id, orderId, productId, variantId, productNameSnapshot, quantity, unitPrice, subtotal, notes),
        payment:Payment!inner(id, orderId, shiftId, method, status, amount, cashReceived, changeAmount, paidAt),
        createdBy:User(id, name, username)
      ''');

      if (storeId.isNotEmpty) {
        query = query.eq('storeId', storeId);
      }

      query = query.eq('payment.shiftId', activeShift.id);

      if (_filterTodayOnly) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
        query = query.gte('createdAt', startOfDay);
      }

      final response = await query.order('createdAt', ascending: false).limit(100);

      final List<OrderModel> fetched = (response as List)
          .map((data) => OrderModel.fromMap(data as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _orders = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat riwayat transaksi: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showOrderDetailSheet(OrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: order.isDineIn ? AppColors.primaryContainer : AppColors.amberLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          order.queueNumber ?? '-',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: order.isDineIn ? AppColors.primaryDark : AppColors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '${order.formattedDate} • ${order.diningLabel}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Daftar Item Pesanan
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Rincian Menu Dipesan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productNameSnapshot,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (item.notes != null && item.notes!.isNotEmpty)
                                      Text(
                                        '* ${item.notes}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.amber,
                                        ),
                                      ),
                                    Text(
                                      item.formattedUnitPrice,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                item.formattedSubtotal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 24),

                      // Rincian Pembayaran
                      const Text(
                        'Informasi Pembayaran',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow('Pelanggan', order.customerNameSnapshot),
                      if (order.cashierName != null)
                        _buildDetailRow('Kasir Bertugas', order.cashierName!),
                      _buildDetailRow('Metode Pembayaran', order.payment?.method ?? 'CASH'),
                      if (order.payment?.method == 'CASH' && order.payment?.cashReceived != null) ...[
                        _buildDetailRow('Bayar Tunai', order.payment!.formattedCashReceived),
                        if (order.payment?.changeAmount != null)
                          _buildDetailRow('Kembalian', order.payment!.formattedChangeAmount),
                      ],
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL AKHIR',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            order.formattedGrandTotal,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tombol Cetak Ulang Struk
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol 1: Cetak Ulang Struk
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final auth = ref.read(authProvider);
                              final printerState = ref.read(printerProvider);

                              if (!printerState.isConnected) {
                                AppToast.showWarning(
                                  context,
                                  'Printer belum terhubung. Buka Pengaturan Printer untuk menyambungkan.',
                                );
                                return;
                              }

                              final success = await ref
                                  .read(printerProvider.notifier)
                                  .printReceipt(
                                    order,
                                    storeName: auth.storeName.isNotEmpty
                                        ? auth.storeName
                                        : 'SCHAW CAFE',
                                    cashierName: auth.userName,
                                    settings: ref.read(storeSettingsProvider).settings,
                                  );

                              if (!mounted) return;
                              if (success) {
                                AppToast.showSuccess(
                                  context,
                                  'Struk transaksi berhasil dicetak ulang!',
                                );
                              } else {
                                AppToast.showError(
                                  context,
                                  'Gagal mencetak struk. Periksa status printer.',
                                );
                              }
                            },
                            icon: const Icon(Icons.print_rounded, size: 20),
                            label: const Text(
                              'Cetak Ulang Struk',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tombol 2: Cetak Ulang Tiket Dapur
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7), // Sky Blue seperti web
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final printerState = ref.read(printerProvider);

                              if (!printerState.isConnected) {
                                AppToast.showWarning(
                                  context,
                                  'Printer belum terhubung. Buka Pengaturan Printer untuk menyambungkan.',
                                );
                                return;
                              }

                              final success = await ref
                                  .read(printerProvider.notifier)
                                  .printKitchenTicket(order);

                              if (!mounted) return;
                              if (success) {
                                AppToast.showSuccess(
                                  context,
                                  'Tiket dapur berhasil dicetak ulang!',
                                );
                              } else {
                                AppToast.showError(
                                  context,
                                  'Gagal mencetak tiket dapur. Periksa status printer.',
                                );
                              }
                            },
                            icon: const Icon(Icons.soup_kitchen_rounded, size: 20),
                            label: const Text(
                              'Cetak Ulang Tiket Dapur',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShift = ref.watch(shiftProvider).activeShift;
    ref.listen(shiftProvider.select((s) => s.activeShift?.id), (previous, next) {
      if (previous != next) {
        _fetchOrders();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Hari Ini'),
                  selected: _filterTodayOnly,
                  onSelected: (selected) {
                    setState(() => _filterTodayOnly = true);
                    _fetchOrders();
                  },
                  selectedColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Semua Transaksi'),
                  selected: !_filterTodayOnly,
                  onSelected: (selected) {
                    setState(() => _filterTodayOnly = false);
                    _fetchOrders();
                  },
                  selectedColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Segarkan Data',
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  onPressed: _fetchOrders,
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchOrders,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchOrders,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : activeShift == null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_clock_outlined, size: 56, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Shift Kasir Belum Dibuka',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Buka shift kasir terlebih dahulu untuk mencatat dan melihat riwayat transaksi sesi ini.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => context.go('/shift'),
                                      icon: const Icon(Icons.meeting_room_rounded, size: 18),
                                      label: const Text('Buka Shift Kasir Sekarang'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _orders.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Belum Ada Transaksi di Shift Ini',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Transaksi penjualan POS yang selesai pada shift ini akan muncul di sini.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final isDineIn = order.isDineIn;

                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  child: InkWell(
                                    onTap: () => _showOrderDetailSheet(order),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Nomor Antrean Badge
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: isDineIn ? AppColors.primaryContainer : AppColors.amberLight,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  order.queueNumber ?? '-',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDineIn ? AppColors.primaryDark : AppColors.amber,
                                                  ),
                                                ),
                                                Text(
                                                  order.diningLabel,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDineIn ? AppColors.primaryDark : AppColors.amber,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),

                                          // Order Number & Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.orderNumber,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${order.customerNameSnapshot} • ${order.formattedTime}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  '${order.items.length} Menu',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Total & Metode Bayar
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                order.formattedGrandTotal,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  order.payment?.method ?? 'PAID',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
