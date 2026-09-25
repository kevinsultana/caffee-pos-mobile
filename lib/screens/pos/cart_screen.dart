import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cart_item_model.dart';
import '../../models/customer_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
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
  late final TextEditingController _customerCtrl;

  @override
  void initState() {
    super.initState();
    _customerCtrl =
        TextEditingController(text: ref.read(cartProvider).customerName);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    super.dispose();
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
              _customerCtrl.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  void _showMemberSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(
        builder: (c, modalRef, child) {
          final cs = modalRef.watch(customerProvider);
          return _MemberSelectorSheet(
            customers: cs.customers,
            isLoading: cs.isLoading,
            selectedCustomerId: ref.read(cartProvider).customerId,
            onSelectGuest: () {
              ref.read(cartProvider.notifier).setCustomer(null);
              Navigator.pop(ctx);
              AppToast.showInfo(context, 'Beralih ke mode Guest');
            },
            onSelectCustomer: (c) {
              ref.read(cartProvider.notifier).setCustomer(c);
              Navigator.pop(ctx);
              AppToast.showSuccess(
                  context, 'Member "${c.name}" teridentifikasi!');
            },
            onCreateNew: () {
              Navigator.pop(ctx);
              _showCreateMemberDialog();
            },
          );
        },
      ),
    );
  }

  void _showCreateMemberDialog({String? initName, String? initPhone}) {
    final nameCtrl = TextEditingController(text: initName ?? '');
    final phoneCtrl = TextEditingController(text: initPhone ?? '');
    final emailCtrl = TextEditingController();
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_add_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Daftar Member Baru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              _field(nameCtrl, 'Nama Lengkap *', 'Contoh: Budi',
                  cap: TextCapitalization.words),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'Nomor Telepon / WA', '08xxxxxxxxxx',
                  keyboard: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              _field(emailCtrl, 'Email (Opsional)', 'budi@example.com',
                  keyboard: TextInputType.emailAddress),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        AppToast.showError(
                            context, 'Nama lengkap wajib diisi');
                        return;
                      }
                      setSt(() => saving = true);
                      try {
                        final newC = await ref
                            .read(customerProvider.notifier)
                            .createCustomer(
                              name: name,
                              phone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              email: emailCtrl.text.trim().isEmpty
                                  ? null
                                  : emailCtrl.text.trim(),
                            );
                        ref.read(cartProvider.notifier).setCustomer(newC);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          HapticFeedback.lightImpact();
                          AppToast.showSuccess(
                              context,
                              'Member baru "${newC.name}" didaftarkan!');
                        }
                      } catch (e) {
                        setSt(() => saving = false);
                        if (mounted) {
                          AppToast.showError(context,
                              'Gagal mendaftar: ${e.toString()}');
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan & Pilih Member'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboard,
    TextCapitalization cap = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textCapitalization: cap,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

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
    ref.listen<CartState>(cartProvider, (prev, next) {
      if (prev?.customerName != next.customerName &&
          _customerCtrl.text != next.customerName) {
        _customerCtrl.text = next.customerName;
      }
    });
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
              if (cart.hasActiveQrOrder)
                SliverToBoxAdapter(child: _qrBanner(cart)),
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

  Widget _qrBanner(CartState cart) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.amberLight,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(6)),
            child: Text('#${cart.activeQrToken}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Pesanan QR Terhubung',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary))),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).detachQrOrder();
              AppToast.showInfo(context, 'Tautan pesanan QR dilepas');
            },
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Lepas Tautan',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber)),
          ),
        ]),
      );

  Widget _orderInfoCard(CartState cart) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<DiningOption>(
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
            const SizedBox(height: 14),
            if (cart.isMemberVerified)
              _memberCard(cart)
            else
              _guestRow(),
            if (cart.unregisteredQrPhone != null &&
                !cart.isMemberVerified) ...[
              const SizedBox(height: 8),
              _unregisteredChip(cart),
            ],
          ],
        ),
      );

  Widget _memberCard(CartState cart) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.stars_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cart.customerName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                if (cart.customerPhone != null &&
                    cart.customerPhone!.isNotEmpty)
                  Text(cart.customerPhone!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace')),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5)),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showMemberSelector,
            child: const Text('Ganti',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      );

  Widget _guestRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _customerCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Nama pelanggan (opsional)',
                hintStyle:
                    TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: Icon(Icons.person_outline_rounded,
                    size: 18, color: AppColors.textMuted),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(cartProvider.notifier).setCustomerName(v),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _showMemberSelector,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.person_search_rounded, size: 16),
            label: const Text('Member',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      );

  Widget _unregisteredChip(CartState cart) => GestureDetector(
        onTap: () => _showCreateMemberDialog(
          initName:
              cart.customerName != 'Pelanggan' ? cart.customerName : '',
          initPhone: cart.unregisteredQrPhone,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.amberLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.amber),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textPrimary),
                  children: [
                    const TextSpan(text: 'No. HP '),
                    TextSpan(
                        text: cart.unregisteredQrPhone,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                    const TextSpan(text: ' belum member — '),
                    const TextSpan(
                        text: 'Daftarkan?',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
          ]),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Member Selector Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _MemberSelectorSheet extends StatefulWidget {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? selectedCustomerId;
  final VoidCallback onSelectGuest;
  final ValueChanged<CustomerModel> onSelectCustomer;
  final VoidCallback onCreateNew;

  const _MemberSelectorSheet({
    required this.customers,
    required this.isLoading,
    this.selectedCustomerId,
    required this.onSelectGuest,
    required this.onSelectCustomer,
    required this.onCreateNew,
  });

  @override
  State<_MemberSelectorSheet> createState() => _MemberSelectorSheetState();
}

class _MemberSelectorSheetState extends State<_MemberSelectorSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      if (_q.trim().isEmpty) return true;
      final q = _q.toLowerCase().trim();
      return c.name.toLowerCase().contains(q) ||
          (c.phone?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, sc) => Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Pilih Pelanggan / Member',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4)),
              onPressed: widget.onCreateNew,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('+ Member Baru',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, nomor HP, atau email...',
              hintStyle: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textMuted),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person_off_rounded,
                            size: 20,
                            color: AppColors.textSecondary),
                      ),
                      title: const Text('Guest (Bukan Member)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Transaksi biasa tanpa poin loyalitas',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      trailing: widget.selectedCustomerId == null
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: widget.onSelectGuest,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(
                          height: 1, color: AppColors.borderLight),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          const Icon(Icons.search_off_rounded,
                              size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            _q.isNotEmpty
                                ? 'Member "$_q" tidak ditemukan'
                                : 'Belum ada data member terdaftar',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          if (_q.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              onPressed: widget.onCreateNew,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Daftarkan "$_q"',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                      )
                    else
                      ...filtered.map((c) {
                        final sel = widget.selectedCustomerId == c.id;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          tileColor:
                              sel ? AppColors.primaryContainer : null,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: sel
                                    ? Colors.white
                                    : AppColors.primaryLight,
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: Icon(Icons.star_rounded,
                                size: 22,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.primaryDark),
                          ),
                          title: Text(c.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary)),
                          subtitle: Text(
                              c.displaySubtitle.isNotEmpty
                                  ? c.displaySubtitle
                                  : 'Member Terdaftar',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          trailing: sel
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 20)
                              : null,
                          onTap: () => widget.onSelectCustomer(c),
                        );
                      }),
                  ],
                ),
        ),
      ]),
    );
  }
}

