import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/online_orders_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/promotion_provider.dart';
import '../../widgets/product_action_sheet.dart';
import '../../core/utils/app_toast.dart';
import 'package:go_router/go_router.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _selectedPosTab = 0; // 0: Katalog Menu, 1: Pesanan QR Online

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(onlineOrdersProvider.notifier).fetchPendingOrders();
      ref.read(promotionProvider.notifier).fetchActivePromotions();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openQrOrder(OrderModel order) {
    final cart = ref.read(cartProvider);
    final catalogState = ref.read(productProvider);

    if (cart.items.isNotEmpty && cart.activeQrOrderId != order.id) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Ganti Isi Keranjang?'),
          content: const Text(
            'Keranjang kasir saat ini memiliki pesanan lain. Timpa isi keranjang dengan pesanan QR ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeLoadQrOrder(order, catalogState.products);
              },
              child: const Text('Muat Pesanan'),
            ),
          ],
        ),
      );
    } else {
      _executeLoadQrOrder(order, catalogState.products);
    }
  }

  Future<void> _executeLoadQrOrder(OrderModel order, List<ProductModel> catalogProducts) async {
    await ref.read(cartProvider.notifier).loadQrOrder(
      order: order,
      catalogProducts: catalogProducts,
    );

    if (!mounted) return;

    final cart = ref.read(cartProvider);
    if (cart.customerId != null) {
      AppToast.showSuccess(
        context,
        'Pesanan QR dimuat! Member "${cart.customerName}" teridentifikasi.',
      );
    } else if (cart.unregisteredQrPhone != null) {
      AppToast.showInfo(
        context,
        'Pesanan QR dimuat. Nomor HP ${cart.unregisteredQrPhone} belum terdaftar sebagai member.',
      );
    } else {
      AppToast.showSuccess(
        context,
        'Pesanan QR #${order.publicQrToken ?? order.orderNumber} dimuat ke keranjang',
      );
    }

    // Beralih ke tab katalog menu dan langsung buka CartScreen
    setState(() {
      _selectedPosTab = 0;
    });

    context.push('/pos/cart');
  }

  void _confirmCancelQrOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Batalkan Pesanan QR?'),
        content: Text(
          'Yakin ingin membatalkan dan menghapus pesanan QR #${order.publicQrToken ?? order.orderNumber} dari ${order.customerNameSnapshot}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(onlineOrdersProvider.notifier)
                  .cancelOrder(order.id);

              if (mounted) {
                if (success) {
                  final cart = ref.read(cartProvider);
                  if (cart.activeQrOrderId == order.id) {
                    ref.read(cartProvider.notifier).clearCart();
                  }
                  AppToast.showSuccess(context, 'Pesanan QR berhasil dibatalkan');
                } else {
                  AppToast.showError(context, 'Gagal membatalkan pesanan QR');
                }
              }
            },
            child: const Text('Batalkan Pesanan'),
          ),
        ],
      ),
    );
  }

  /// Menangani pencarian dengan Debounce 500ms
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(productProvider.notifier).setSearchQuery(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(productProvider.notifier).setSearchQuery('');
  }

  void _handleProductTap(ProductModel product) {
    if (product.hasVariants) {
      // Buka bottom sheet pemilihan varian
      ProductActionSheet.show(context, product);
    } else {
      // Langsung masukkan ke keranjang jika tanpa varian
      ref.read(cartProvider.notifier).addToCart(
        product: product,
        quantity: 1,
      );

      AppToast.showSuccess(
        context,
        '${product.name} ditambahkan ke keranjang',
        duration: const Duration(milliseconds: 1500),
      );
    }
  }

  /// Modal dialog untuk kasir membuka shift baru dari halaman POS
  Future<void> _showOpenShiftDialog() async {
    final cashController = TextEditingController(text: '100000');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Buka Shift Kasir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan jumlah kas modal awal di laci kasir untuk mulai melayani transaksi:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cashController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Modal Awal (Rp)',
                        prefixText: 'Rp ',
                        hintText: '100000',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Modal awal wajib diisi';
                        }
                        final amount = double.tryParse(val);
                        if (amount == null || amount < 0) {
                          return 'Masukkan nominal yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [50000, 100000, 200000, 500000].map((nominal) {
                        return ActionChip(
                          label: Text(
                            NumberFormat.compactSimpleCurrency(locale: 'id_ID').format(nominal),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              cashController.text = nominal.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Buka Shift'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final amount = double.tryParse(cashController.text) ?? 0.0;
    final error = await ref.read(shiftProvider.notifier).openShift(openingCash: amount);

    if (!mounted) return;

    if (error != null) {
      AppToast.showError(context, error);
    } else {
      AppToast.showSuccess(
        context,
        'Shift berhasil dibuka! Selamat bertugas melayani pesanan.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final authState = ref.watch(authProvider);
    final catalogState = ref.watch(productProvider);
    final cartState = ref.watch(cartProvider);
    final onlineOrders = ref.watch(onlineOrdersProvider);

    // 1. Loading Cek Shift
    if (shiftState.isLoading && shiftState.activeShift == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 2. Proteksi Kasir: Jika belum memiliki shift aktif milik akun ini
    if (!shiftState.hasActiveShift) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(shiftProvider.notifier).checkActiveShift();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: shiftState.isBlockedByOtherShift
                    ? _buildShiftBlockedView(context, shiftState, authState)
                    : _buildNeedOpenShiftView(context, shiftState, authState),
              ),
            ),
          ),
        ),
      );
    }

    // 3. Shift Aktif Valid: Buka Akses Kasir (POS)
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (_selectedPosTab == 0)
            RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(productProvider.notifier).fetchCatalog(),
                  ref.read(onlineOrdersProvider.notifier).fetchPendingOrders(),
                ]);
              },
              child: CustomScrollView(
                slivers: [
                  // Tab Switcher Header (Katalog Menu vs Pesanan QR Online)
                  SliverToBoxAdapter(
                    child: _buildPosTabSwitcher(onlineOrders),
                  ),

                  // 1. Search Bar Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari kopi, makanan, cemilan...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Horizontal Filter Kategori
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogState.categories.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final isSelected = isAll
                            ? catalogState.selectedCategoryId == null
                            : catalogState.selectedCategoryId == catalogState.categories[index - 1].id;

                        final label = isAll ? 'Semua Menu' : catalogState.categories[index - 1].name;

                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (_) {
                            final catId = isAll ? null : catalogState.categories[index - 1].id;
                            ref.read(productProvider.notifier).selectCategory(catId);
                          },
                          label: Text(label),
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 3. Grid Katalog Produk
                if (catalogState.isLoading && catalogState.products.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (catalogState.filteredProducts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Menu tidak ditemukan',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Coba kata kunci lain atau ganti kategori',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      cartState.isNotEmpty ? 100 : 24, // beri ruang ekstra jika ada floating cart
                    ),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = catalogState.filteredProducts[index];
                          return _buildProductCard(context, product, cartState);
                        },
                        childCount: catalogState.filteredProducts.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tampilan Tab Pesanan QR Online
          if (_selectedPosTab == 1)
            _buildOnlineOrdersView(context, onlineOrders, cartState),

          // 4. Floating Cart Bar (muncul jika ada item di keranjang)
          if (cartState.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingCartBar(context, cartState),
            ),
        ],
      ),
    );
  }

  /// Tab Selector Switcher (Katalog Menu POS vs Pesanan QR Online)
  Widget _buildPosTabSwitcher(OnlineOrdersState onlineOrders) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedPosTab = 0),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _selectedPosTab == 0 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 16,
                        color: _selectedPosTab == 0 ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Katalog Menu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedPosTab == 0 ? FontWeight.bold : FontWeight.w600,
                          color: _selectedPosTab == 0 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _selectedPosTab = 1);
                  ref.read(onlineOrdersProvider.notifier).fetchPendingOrders();
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _selectedPosTab == 1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 16,
                        color: _selectedPosTab == 1 ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pesanan QR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedPosTab == 1 ? FontWeight.bold : FontWeight.w600,
                          color: _selectedPosTab == 1 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      if (onlineOrders.pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _selectedPosTab == 1 ? Colors.white : AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${onlineOrders.pendingCount}',
                            style: TextStyle(
                              color: _selectedPosTab == 1 ? AppColors.primaryDark : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan Tab Daftar Pesanan QR Online
  Widget _buildOnlineOrdersView(
    BuildContext context,
    OnlineOrdersState onlineOrders,
    CartState cartState,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(onlineOrdersProvider.notifier).fetchPendingOrders(),
      child: CustomScrollView(
        slivers: [
          // Tab Switcher Header
          SliverToBoxAdapter(
            child: _buildPosTabSwitcher(onlineOrders),
          ),

          if (onlineOrders.isLoading && onlineOrders.orders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (onlineOrders.orders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 52,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Tidak Ada Pesanan Online Menunggu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saat pelanggan memesan melalui menu QR publik di meja, pesanan yang menunggu pembayaran akan otomatis tampil di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(onlineOrdersProvider.notifier).fetchPendingOrders(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Segarkan Antrean'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                cartState.isNotEmpty ? 100 : 24,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = onlineOrders.orders[index];
                    return _buildOnlineOrderCard(context, order);
                  },
                  childCount: onlineOrders.orders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Kartu Rincian Pesanan QR Online
  Widget _buildOnlineOrderCard(BuildContext context, OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Token Badge, Order Number & Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        order.publicQrToken != null
                            ? '#${order.publicQrToken}'
                            : '#QR',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.minutesLeft <= 10 ? AppColors.roseLight : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: order.minutesLeft <= 10 ? AppColors.rose : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${order.minutesLeft} mnt tersisa',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: order.minutesLeft <= 10 ? AppColors.rose : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info Pemesan
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customerNameSnapshot,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (order.queueNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (order.queueNumber!.startsWith('TA') || order.queueNumber!.startsWith('T'))
                          ? AppColors.amberLight
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Antrean: ${order.queueNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (order.queueNumber!.startsWith('TA') || order.queueNumber!.startsWith('T'))
                            ? AppColors.amber
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
            if (order.customerPhoneSnapshot != null && order.customerPhoneSnapshot!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                  'WA: ${order.customerPhoneSnapshot}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                'Dipesan: ${order.formattedTime}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),

            // Rincian Item Pesanan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: order.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${it.quantity}x ${it.productNameSnapshot}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              it.formattedSubtotal,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (it.notes != null && it.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 11, color: AppColors.amber),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  it.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Total Tagihan & Tombol Aksi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Tagihan:',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Text(
                      order.formattedGrandTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _confirmCancelQrOrder(order),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      tooltip: 'Batalkan Pesanan QR',
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () => _openQrOrder(order),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Row(
                        children: [
                          Text('Buka di Kasir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan placeholder jika gambar produk kosong atau gagal dimuat
  Widget _buildFallbackImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF1F5F9), // slate-100 seperti di web menu
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_outlined,
            size: 36,
            color: Color(0xFF94A3B8), // slate-400
          ),
          SizedBox(height: 4),
          Text(
            'Foto Menu',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Tampilan Produk (Desain Edge-to-Edge Photo identik dengan web /menu)
  Widget _buildProductCard(BuildContext context, ProductModel product, CartState cartState) {
    // Hitung total item produk ini yang sudah ada di keranjang
    final cartQuantity = cartState.items
        .where((i) => i.productId == product.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);

    final isOutOfStock = !product.isAvailable;

    return InkWell(
      onTap: isOutOfStock ? null : () => _handleProductTap(product),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias, // Memastikan foto melengkung sempurna mengikuti sudut kartu
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── BAGIAN ATAS: FOTO BESAR ASPECT RATIO PERSEGI (Edge-to-Edge) ───
            AspectRatio(
              aspectRatio: 1.05,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProductImage(product),

                  // Badge "Ada Varian" di Pojok Kanan Atas
                  if (product.hasVariants && !isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Ada Varian',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Badge Kuantitas di Keranjang (Pojok Kiri Atas)
                  if (cartQuantity > 0 && !isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${cartQuantity}x',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Overlay Menu Habis (Out of Stock)
                  if (isOutOfStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.rose,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HABIS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── BAGIAN BAWAH: INFORMASI MENU & TOMBOL AKSI ───────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label Kategori Menu
                        Text(
                          (product.categoryName ?? 'MENU').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),

                        // Nama Menu
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isOutOfStock ? AppColors.textMuted : AppColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Baris Harga & Tombol Tambah
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            product.formattedPrice,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isOutOfStock ? AppColors.textMuted : AppColors.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? AppColors.surfaceMuted
                                : (cartQuantity > 0 ? AppColors.primaryDark : AppColors.primary),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isOutOfStock
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            cartQuantity > 0 ? Icons.check_rounded : Icons.add_rounded,
                            color: isOutOfStock ? AppColors.textMuted : Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper untuk merender gambar produk dengan caching disk dan fallback yang rapi
  Widget _buildProductImage(ProductModel product) {
    final url = product.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        // Tunjukkan spinner tipis saat gambar sedang diunduh
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Fallback ikon kopi jika URL gambar gagal dimuat
        errorWidget: (context, url, error) => _buildFallbackImage(),
        // Batasi ukuran memori: maksimal 100×100 px di memori cache
        memCacheWidth: 200,
        memCacheHeight: 200,
      );
    }
    return _buildFallbackImage();
  }

  /// Floating Cart Bar Melayang di Bawah
  Widget _buildFloatingCartBar(BuildContext context, CartState cart) {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/pos/cart'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Badge Jumlah Item
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Rincian Total Harga & Item
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.totalItems} Item • ${cart.diningOption.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      cart.formattedTotalPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // CTA Lihat Keranjang
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Keranjang',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tampilan ketika kasir lain sedang shift dan batas toko sudah tercapai (Akses POS Ditutup)
  Widget _buildShiftBlockedView(
    BuildContext context,
    ShiftState shiftState,
    AuthState authState,
  ) {
    final activeOther = shiftState.otherActiveShifts.isNotEmpty
        ? shiftState.otherActiveShifts.first
        : null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.roseLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                size: 34,
                color: AppColors.rose,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.roseLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Batas Shift Toko Tercapai (${shiftState.maxActiveShifts}/${shiftState.maxActiveShifts})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.rose,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Shift Sedang Berjalan Oleh Kasir Lain',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Akun Anda (${authState.userName}) belum dapat mengakses kasir karena ada shift kasir lain yang sedang berjalan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Card Info Kasir yang Sedang Bertugas
            if (activeOther != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kasir Bertugas:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            activeOther.userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dibuka Sejak:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            activeOther.formattedOpenedAt,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),
            Text(
              'Pengaturan toko membatasi maksimal ${shiftState.maxActiveShifts} shift aktif bersamaan. Anda baru dapat membuka kasir setelah kasir di atas menutup shift-nya, atau setelah Owner mengubah pengaturan batas shift toko menjadi lebih dari 1.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Refresh Status
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => ref.read(shiftProvider.notifier).checkActiveShift(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Cek Ulang Status Shift',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan ketika kasir belum buka shift tapi toko mengizinkan buka shift
  Widget _buildNeedOpenShiftView(
    BuildContext context,
    ShiftState shiftState,
    AuthState authState,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            if (shiftState.otherActiveShifts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Multi-Shift (${shiftState.totalStoreOpenShifts}/${shiftState.maxActiveShifts} Slot Aktif)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'Buka Shift Kasir Terlebih Dahulu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Halo ${authState.userName}, silakan buka sesi shift dan masukkan modal awal di laci kasir untuk mulai melayani transaksi pemesanan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _showOpenShiftDialog,
                icon: const Icon(Icons.lock_open_rounded, size: 20),
                label: const Text(
                  'Buka Shift Kasir Sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
