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

  void _showMemberSelectorModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, modalRef, child) {
            final customerState = modalRef.watch(customerProvider);
            return _MemberSelectorSheetContent(
              customers: customerState.customers,
              isLoading: customerState.isLoading,
              selectedCustomerId: ref.read(cartProvider).customerId,
              onSelectGuest: () {
                ref.read(cartProvider.notifier).setCustomer(null);
                Navigator.pop(ctx);
                AppToast.showInfo(context, 'Beralih ke mode Guest (Bukan Member)');
              },
              onSelectCustomer: (customer) {
                ref.read(cartProvider.notifier).setCustomer(customer);
                Navigator.pop(ctx);
                AppToast.showSuccess(context, 'Member "${customer.name}" teridentifikasi!');
              },
              onCreateNew: () {
                Navigator.pop(ctx);
                _showCreateCustomerDialog(context);
              },
            );
          },
        );
      },
    );
  }

  void _showCreateCustomerDialog(
    BuildContext context, {
    String? initialName,
    String? initialPhone,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    final phoneController = TextEditingController(text: initialPhone ?? '');
    final emailController = TextEditingController();
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
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
                    child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Daftar Member Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap *',
                        hintText: 'Contoh: Budi Santoso',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon / WhatsApp',
                        hintText: '08xxxxxxxxxx',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email (Opsional)',
                        hintText: 'budi@example.com',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            AppToast.showError(context, 'Nama lengkap wajib diisi');
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            final newCustomer = await ref
                                .read(customerProvider.notifier)
                                .createCustomer(
                                  name: name,
                                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                );

                            // Otomatis pasang member baru ke keranjang
                            ref.read(cartProvider.notifier).setCustomer(newCustomer);

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              HapticFeedback.lightImpact();
                              AppToast.showSuccess(context, 'Member baru "${newCustomer.name}" berhasil didaftarkan!');
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              AppToast.showError(context, 'Gagal mendaftarkan member: ${e.toString()}');
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan & Pilih Member'),
                ),
              ],
            );
          },
        );
      },
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

                // 1.5. Informasi Member & Identifikasi Pelanggan
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'PELANGGAN / MEMBER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (cart.isMemberVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 10, color: AppColors.primaryDark),
                                      SizedBox(width: 3),
                                      Text(
                                        'Member Terverifikasi',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          InkWell(
                            onTap: () => _showCreateCustomerDialog(context),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add_rounded, size: 13, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    '+ Member Baru',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Tampilan Member yang dipilih atau tombol pilih member
                      if (cart.isMemberVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cart.customerName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (cart.customerPhone != null && cart.customerPhone!.isNotEmpty)
                                      Text(
                                        cart.customerPhone!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                  foregroundColor: AppColors.error,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).setCustomer(null);
                                  AppToast.showInfo(context, 'Beralih ke mode Guest (Bukan Member)');
                                },
                                child: const Text('Ganti / Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _showMemberSelectorModal(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textSecondary),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Guest (Bukan Member)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        'Pilih member terdaftar untuk akumulasi poin & promo',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),

                      // ── BANNER PERINGATAN MEMBER BARU DARI QR ──
                      if (cart.unregisteredQrPhone != null && !cart.isMemberVerified) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amberLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Nomor HP '),
                                          TextSpan(
                                            text: cart.unregisteredQrPhone,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' belum terdaftar sebagai member. Tawarkan pendaftaran member kepada pelanggan.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    _showCreateCustomerDialog(
                                      context,
                                      initialName: cart.customerName != 'Pelanggan' ? cart.customerName : '',
                                      initialPhone: cart.unregisteredQrPhone,
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text(
                                    'Daftarkan sebagai Member',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Nama Pelanggan / Meja',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                                if (cart.isMemberVerified)
                                  const Text(
                                    'Terkunci (Member)',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: cart.isMemberVerified ? AppColors.primaryContainer : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: cart.isMemberVerified ? AppColors.primaryLight : AppColors.border,
                                ),
                              ),
                              child: cart.isMemberVerified
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 15, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              cart.customerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : TextField(
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
                                    ? CachedNetworkImage(
                                        imageUrl: item.productImageUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 100,
                                        memCacheHeight: 100,
                                        placeholder: (context, url) => const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => const Icon(
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
                        // ── TRIGGER KUPON / PROMO ──
                        if (cart.appliedPromo != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryLight, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.confirmation_number_rounded, color: AppColors.primaryDark, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            cart.appliedPromo!.code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(-${cart.formattedPromotionDiscount})',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        cart.appliedPromo!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => PromoSheet.show(context),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  child: const Text('Ganti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    ref.read(cartProvider.notifier).removePromo();
                                    AppToast.showInfo(context, 'Promo diskon dilepas');
                                  },
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => PromoSheet.show(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Pilih Promo Diskon',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    const Spacer(),
                                    Consumer(
                                      builder: (ctx, refCount, _) {
                                        final count = refCount.watch(promotionProvider).promotions.length;
                                        if (count > 0) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$count Promo',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Rincian Subtotal jika ada diskon promo
                        if (cart.hasAppliedPromo) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Text(
                                cart.formattedTotalPrice,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Diskon Promo (${cart.appliedPromo!.code})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              Text(
                                '-${cart.formattedPromotionDiscount}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: AppColors.borderLight),
                          const SizedBox(height: 6),
                        ],

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
                              cart.formattedGrandTotal,
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

class _MemberSelectorSheetContent extends StatefulWidget {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? selectedCustomerId;
  final VoidCallback onSelectGuest;
  final ValueChanged<CustomerModel> onSelectCustomer;
  final VoidCallback onCreateNew;

  const _MemberSelectorSheetContent({
    required this.customers,
    required this.isLoading,
    this.selectedCustomerId,
    required this.onSelectGuest,
    required this.onSelectCustomer,
    required this.onCreateNew,
  });

  @override
  State<_MemberSelectorSheetContent> createState() => _MemberSelectorSheetContentState();
}

class _MemberSelectorSheetContentState extends State<_MemberSelectorSheetContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final nameMatches = c.name.toLowerCase().contains(q);
      final phoneMatches = c.phone?.toLowerCase().contains(q) ?? false;
      final emailMatches = c.email?.toLowerCase().contains(q) ?? false;
      return nameMatches || phoneMatches || emailMatches;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Pilih Pelanggan / Member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: widget.onCreateNew,
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('+ Member Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari nama, nomor HP, atau email...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

            const Divider(height: 1),

            // List of Options
            Expanded(
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // Option: Guest
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_off_rounded, size: 20, color: AppColors.textSecondary),
                          ),
                          title: const Text(
                            'Guest (Bukan Member)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Transaksi kasir biasa tanpa poin loyalitas',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: widget.selectedCustomerId == null
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                              : null,
                          onTap: widget.onSelectGuest,
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Divider(height: 1, color: AppColors.borderLight),
                        ),

                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Member "$_searchQuery" tidak ditemukan'
                                      : 'Belum ada data member terdaftar',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: widget.onCreateNew,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text(
                                      'Daftarkan "$_searchQuery"',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          ...filtered.map((customer) {
                            final isSelected = widget.selectedCustomerId == customer.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              tileColor: isSelected ? AppColors.primaryContainer : null,
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 22,
                                  color: isSelected ? AppColors.primary : AppColors.primaryDark,
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                customer.displaySubtitle.isNotEmpty
                                    ? customer.displaySubtitle
                                    : 'Member Terdaftar',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                  : null,
                              onTap: () => widget.onSelectCustomer(customer),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
