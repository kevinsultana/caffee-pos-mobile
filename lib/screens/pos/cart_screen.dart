import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/promotion_provider.dart';
import 'promo_sheet.dart';

/// Full-screen cart page — route `/pos/cart`.
/// Registered OUTSIDE the StatefulShellRoute so the BottomNav is hidden.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(promotionProvider.notifier).fetchActivePromotions();
    });
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Kosongkan Keranjang?'),
        content: const Text(
            'Semua item pesanan yang telah dipilih akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
            },
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(CartItemModel item) {
    final ctrl = TextEditingController(text: item.notes ?? '');
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    final presets = [
      'Less Sugar', 'No Sugar', 'Normal Ice', 'Less Ice',
      'No Ice', 'Extra Hot', 'Pisah Saus', 'Pedas Sedang', 'Tidak Pedas',
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_note_rounded,
                  color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catatan Pesanan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    '${item.productName}'
                    '${item.variantName != null ? " (${item.variantName})" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 2,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setSt(() {}),
                decoration: InputDecoration(
                  hintText: 'Contoh: Less sugar, extra ice...',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(10),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              const Text('Pilihan Cepat:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((p) {
                  final cur = ctrl.text;
                  final has = cur
                      .split(',')
                      .map((s) => s.trim().toLowerCase())
                      .contains(p.toLowerCase());
                  return InkWell(
                    onTap: () => setSt(() {
                      if (cur.trim().isEmpty) {
                        ctrl.text = p;
                      } else if (!has) {
                        ctrl.text = '${cur.trim()}, $p';
                      } else {
                        ctrl.text = cur
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) =>
                                e.toLowerCase() != p.toLowerCase())
                            .join(', ');
                      }
                      ctrl.selection = TextSelection.collapsed(
                          offset: ctrl.text.length);
                    }),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: has
                            ? AppColors.primaryContainer
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                has ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (has) ...[
                            const Icon(Icons.check_rounded,
                                size: 12, color: AppColors.primaryDark),
                            const SizedBox(width: 4),
                          ],
                          Text(p,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: has
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: has
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (item.notes != null && item.notes!.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error),
                onPressed: () {
                  ref
                      .read(cartProvider.notifier)
                      .updateItemNotes(item.id, null);
                  Navigator.pop(ctx);
                  AppToast.showInfo(context, 'Catatan dihapus');
                },
                child: const Text('Hapus'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final n = ctrl.text.trim();
                ref
                    .read(cartProvider.notifier)
                    .updateItemNotes(item.id, n.isEmpty ? null : n);
                Navigator.pop(ctx);
                AppToast.showSuccess(context,
                    n.isEmpty ? 'Catatan dihapus' : 'Catatan disimpan');
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: _appBar(cart),
      body: cart.isEmpty ? _emptyState() : _cartBody(cart),
    );
  }

  PreferredSizeWidget _appBar(CartState cart) => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keranjang Pesanan',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('${cart.totalItems} item dipilih',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmClearCart,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.error),
              label: const Text('Kosongkan',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
        ],
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted, shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_outlined,
                    size: 60, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              const Text('Keranjang Masih Kosong',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Pilih produk dari menu kasir untuk menambahkan item.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Kembali ke Menu'),
              ),
            ],
          ),
        ),
      );

  Widget _cartBody(CartState cart) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          Expanded(
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _orderInfoCard(cart)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(children: [
                    const Icon(Icons.swipe_left_rounded,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Geser kiri untuk hapus item',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    const Spacer(),
                    Text(cart.diningOption.label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final item = cart.items[i];
                    return Column(children: [
                      Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Hapus',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              SizedBox(width: 6),
                              Icon(Icons.delete_forever_rounded,
                                  color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          ref
                              .read(cartProvider.notifier)
                              .removeItem(item.id);
                          AppToast.showInfo(
                              context, '${item.productName} dihapus',
                              duration: const Duration(seconds: 1));
                        },
                        child: _itemRow(item),
                      ),
                      if (i < cart.items.length - 1)
                        const Divider(height: 1, indent: 76, endIndent: 20),
                    ]);
                  },
                  childCount: cart.items.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ]),
          ),
          _stickyFooter(cart),
        ]),
      );

  Widget _orderInfoCard(CartState cart) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DiningOption>(
                segments: const [
                  ButtonSegment(
                      value: DiningOption.dineIn,
                      label: Text('Dine-in'),
                      icon: Icon(Icons.restaurant_rounded)),
                  ButtonSegment(
                      value: DiningOption.takeaway,
                      label: Text('Takeaway'),
                      icon: Icon(Icons.shopping_bag_rounded)),
                ],
                selected: {cart.diningOption},
                onSelectionChanged: (s) => ref
                    .read(cartProvider.notifier)
                    .setDiningOption(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primaryContainer,
                  selectedForegroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            if (cart.hasActiveQrOrder) ...[
              const SizedBox(height: 8),
              _qrIndicator(cart),
            ],
          ],
        ),
      );

  Widget _qrIndicator(CartState cart) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.amberLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded,
                size: 15, color: AppColors.amber),
            const SizedBox(width: 6),
            Text(
              'Pesanan QR #${cart.activeQrToken}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                ref.read(cartProvider.notifier).detachQrOrder();
                AppToast.showInfo(context, 'Tautan pesanan QR dilepas');
              },
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lepas',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.close_rounded,
                        size: 12, color: AppColors.amber),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _itemRow(CartItemModel item) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: (item.productImageUrl != null &&
                        item.productImageUrl!.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: item.productImageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 108,
                        memCacheHeight: 108,
                        placeholder: (c, url) => Container(
                            color: AppColors.primaryContainer,
                            child: const Center(
                                child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary)))),
                        errorWidget: (c, url, err) => _thumb(),
                      )
                    : _thumb(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  if (item.variantName != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('Varian: ${item.variantName}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showNotesDialog(item),
                    borderRadius: BorderRadius.circular(6),
                    child: (item.notes != null && item.notes!.isNotEmpty)
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.amberLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.amber
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.edit_note_rounded,
                                  size: 13, color: AppColors.amber),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text(item.notes!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.amber))),
                            ]),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(Icons.add_comment_outlined,
                                  size: 12,
                                  color: AppColors.primaryDark
                                      .withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text('+ Catatan',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark
                                          .withValues(alpha: 0.8))),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.formattedUnitPrice,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.formattedSubtotal,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .decrementQuantity(item.id),
                        child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.remove, size: 16))),
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${item.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13))),
                    InkWell(
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .incrementQuantity(item.id),
                        child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.add, size: 16))),
                  ]),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _thumb() => Container(
      color: AppColors.primaryContainer,
      child: const Icon(Icons.coffee_rounded,
          color: AppColors.primary, size: 26));

  Widget _stickyFooter(CartState cart) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _promoTrigger(cart),
              const SizedBox(height: 10),
              if (cart.hasAppliedPromo) ...[
                _priceRow('Subtotal', cart.formattedTotalPrice,
                    lStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    vColor: AppColors.textSecondary),
                const SizedBox(height: 3),
                _priceRow('Diskon (${cart.appliedPromo!.code})',
                    '-${cart.formattedPromotionDiscount}',
                    lStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                    vColor: AppColors.primary),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 8),
              ],
              _priceRow('Total Pembayaran', cart.formattedGrandTotal,
                  lStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                  vStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.push('/pos/checkout'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lanjut ke Pembayaran  •  ${cart.formattedGrandTotal}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _promoTrigger(CartState cart) {
    if (cart.appliedPromo != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryLight, width: 1.5),
        ),
        child: Row(children: [
          const Icon(Icons.confirmation_number_rounded,
              color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(cart.appliedPromo!.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.primaryDark)),
                  const SizedBox(width: 6),
                  Text('(-${cart.formattedPromotionDiscount})',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ]),
                Text(cart.appliedPromo!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => PromoSheet.show(context),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6)),
            child: const Text('Ganti',
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ref.read(cartProvider.notifier).removePromo();
              AppToast.showInfo(context, 'Promo dilepas');
            },
          ),
        ]),
      );
    }
    return InkWell(
      onTap: () => PromoSheet.show(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.local_offer_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Pilih Promo Diskon',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Spacer(),
          Consumer(builder: (c, r, child) {
            final n = r.watch(promotionProvider).promotions.length;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('$n Promo',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
            );
          }),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _priceRow(String label, String value,
          {TextStyle? lStyle, Color? vColor, TextStyle? vStyle}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: lStyle ??
                  const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style: vStyle ??
                  TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: vColor ?? AppColors.textPrimary)),
        ],
      );
}

