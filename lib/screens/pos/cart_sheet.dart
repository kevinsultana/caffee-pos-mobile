import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';

class CartSheet extends ConsumerStatefulWidget {
  const CartSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CartSheet(),
    );
  }

  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  late final TextEditingController _queueController;
  late final TextEditingController _customerController;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _queueController = TextEditingController(text: cart.queueInput);
    _customerController = TextEditingController(text: cart.customerName);
  }

  @override
  void dispose() {
    _queueController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _confirmClearCart(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Semua item pesanan yang telah dipilih akan dihapus dari keranjang.'),
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
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              _queueController.clear();
              _customerController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(BuildContext context, WidgetRef ref, CartItemModel item) {
    final controller = TextEditingController(text: item.notes ?? '');
    controller.selection = TextSelection.collapsed(offset: controller.text.length);

    final quickNotes = [
      'Less Sugar',
      'No Sugar',
      'Normal Ice',
      'Less Ice',
      'No Ice',
      'Extra Hot',
      'Pisah Saus',
      'Pedas Sedang',
      'Tidak Pedas',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Pesanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.productName}${item.variantName != null ? " (${item.variantName})" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 2,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Contoh: Less sugar, extra ice, tanpa saus...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(10),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilihan Cepat:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickNotes.map((preset) {
                      final currentText = controller.text;
                      final isAlreadyAdded = currentText
                          .split(',')
                          .map((s) => s.trim().toLowerCase())
                          .contains(preset.toLowerCase());

                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            if (currentText.trim().isEmpty) {
                              controller.text = preset;
                            } else if (!isAlreadyAdded) {
                              controller.text = '${currentText.trim()}, $preset';
                            } else {
                              // Toggle: hapus jika sudah ada
                              final parts = currentText
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.toLowerCase() != preset.toLowerCase())
                                  .toList();
                              controller.text = parts.join(', ');
                            }
                            controller.selection = TextSelection.collapsed(offset: controller.text.length);
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAlreadyAdded ? AppColors.primaryContainer : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAlreadyAdded ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAlreadyAdded) ...[
                                const Icon(Icons.check_rounded, size: 12, color: AppColors.primaryDark),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                preset,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isAlreadyAdded ? FontWeight.w700 : FontWeight.w500,
                                  color: isAlreadyAdded ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                if (item.notes != null && item.notes!.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).updateItemNotes(item.id, null);
                      Navigator.pop(ctx);
                      AppToast.showInfo(context, 'Catatan pesanan dihapus');
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Hapus'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newNotes = controller.text.trim();
                    ref.read(cartProvider.notifier).updateItemNotes(
                      item.id,
                      newNotes.isEmpty ? null : newNotes,
                    );
                    Navigator.pop(ctx);
                    AppToast.showSuccess(
                      context,
                      newNotes.isEmpty ? 'Catatan pesanan dihapus' : 'Catatan pesanan disimpan',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    ref.listen<CartState>(cartProvider, (prev, next) {
      if (prev?.queueInput != next.queueInput && _queueController.text != next.queueInput) {
        _queueController.text = next.queueInput;
      }
      if (prev?.customerName != next.customerName && _customerController.text != next.customerName) {
        _customerController.text = next.customerName;
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keranjang Pesanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              '${cart.totalItems} Item Dipilih',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearCart(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              label: const Text(
                'Kosongkan',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 56,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Keranjang Masih Kosong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih produk dari menu kasir untuk menambahkan item ke dalam pesanan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali ke Menu'),
                    ),
                  ],
                ),
              ),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Column(
              children: [
                // 0. Banner Pesanan QR Terhubung (jika ada)
                if (cart.hasActiveQrOrder)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${cart.activeQrToken}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pesanan QR Terhubung',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(cartProvider.notifier).detachQrOrder();
                            AppToast.showInfo(context, 'Tautan pesanan QR dilepas');
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Lepas Tautan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amber)),
                        ),
                      ],
                    ),
                  ),

                // 1. Pilihan Dine-in vs Takeaway
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: SegmentedButton<DiningOption>(
                    segments: const [
                      ButtonSegment(
                        value: DiningOption.dineIn,
                        label: Text('Dine-in (Meja)'),
                        icon: Icon(Icons.restaurant_rounded),
                      ),
                      ButtonSegment(
                        value: DiningOption.takeaway,
                        label: Text('Takeaway (Bungkus)'),
                        icon: Icon(Icons.shopping_bag_rounded),
                      ),
                    ],
                    selected: {cart.diningOption},
                    onSelectionChanged: (selected) {
                      ref.read(cartProvider.notifier).setDiningOption(selected.first);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primaryContainer,
                      selectedForegroundColor: AppColors.primaryDark,
                    ),
                  ),
                ),

                // 2. Input Nomor Antrean (Wajib) & Nama Pelanggan
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nomor Antrean (Wajib *)
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Antrean',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                                const Text(
                                  ' *',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cart.diningOption == DiningOption.takeaway ? AppColors.amberLight : AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cart.diningOption.shortCode,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: cart.diningOption == DiningOption.takeaway ? AppColors.amber : AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: cart.queueInput.trim().isEmpty ? AppColors.error.withValues(alpha: 0.8) : AppColors.border,
                                  width: cart.queueInput.trim().isEmpty ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: cart.diningOption == DiningOption.takeaway
                                          ? AppColors.amberLight
                                          : AppColors.primaryContainer,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                      border: const Border(
                                        right: BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${cart.diningOption.shortCode}-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: cart.diningOption == DiningOption.takeaway
                                            ? AppColors.amber
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _queueController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                        color: cart.queueInput.trim().isEmpty ? AppColors.error : AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Wajib',
                                        hintStyle: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        ref.read(cartProvider.notifier).setQueueInput(val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nama Pelanggan / Meja
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nama Pelanggan / Meja',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _customerController,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: 'Pelanggan',
                                  hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textMuted),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  ref.read(cartProvider.notifier).setCustomerName(val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 3. Petunjuk Swipe to Delete
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.swipe_left_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      const Text(
                        'Geser item ke kiri untuk menghapus',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const Spacer(),
                      Text(
                        cart.fullQueueNumber.isNotEmpty
                            ? 'Antrean: ${cart.fullQueueNumber}'
                            : 'Kode: ${cart.diningOption.shortCode}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cart.fullQueueNumber.isNotEmpty ? AppColors.primaryDark : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Daftar Item Keranjang dengan Dismissible
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];

                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Hapus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          ref.read(cartProvider.notifier).removeItem(item.id);
                          AppToast.showInfo(
                            context,
                            '${item.productName} dihapus dari keranjang',
                            duration: const Duration(seconds: 1),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail / Gambar Produk
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: (item.productImageUrl != null && item.productImageUrl!.trim().isNotEmpty)
                                    ? Image.network(
                                        item.productImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.coffee_rounded,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.coffee_rounded,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Detail Item
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (item.variantName != null) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Varian: ${item.variantName}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  // Catatan Item (Bisa diklik untuk tambah/edit)
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _showNotesDialog(context, ref, item),
                                    borderRadius: BorderRadius.circular(6),
                                    child: (item.notes != null && item.notes!.isNotEmpty)
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.amberLight.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.amber.withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.edit_note_rounded,
                                                  size: 14,
                                                  color: AppColors.amber,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    item.notes!,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.amber,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.edit_rounded,
                                                  size: 10,
                                                  color: AppColors.amber,
                                                ),
                                              ],
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.add_comment_outlined,
                                                  size: 12,
                                                  color: AppColors.primaryDark.withValues(alpha: 0.8),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '+ Catatan',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primaryDark.withValues(alpha: 0.9),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.formattedUnitPrice,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Stepper Qty & Subtotal
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.formattedSubtotal,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => ref
                                            .read(cartProvider.notifier)
                                            .decrementQuantity(item.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.remove, size: 16),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => ref
                                            .read(cartProvider.notifier)
                                            .incrementQuantity(item.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 4. Footer Checkout
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pembayaran',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              cart.formattedTotalPrice,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              final currentCart = ref.read(cartProvider);
                              if (currentCart.queueInput.trim().isEmpty) {
                                AppToast.showError(
                                  context,
                                  'Nomor antrean wajib diisi! Masukkan angka antrean.',
                                );
                                return;
                              }
                              Navigator.pop(context);
                              context.push('/pos/checkout');
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payment_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Lanjut Pembayaran',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
}
