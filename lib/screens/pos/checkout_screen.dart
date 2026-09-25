import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import '../../models/store_settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../services/checkout_service.dart';
import 'member_selector_sheet.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _customerNameController = TextEditingController(text: 'Pelanggan');
  final _cashController = TextEditingController();
  late final TextEditingController _queueController;
  String _paymentMethod = 'CASH'; // 'CASH' or 'QRIS'
  bool _autoPrintReceipt = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _queueController = TextEditingController(text: cart.queueInput);

    // Default isi uang tunai dengan nominal pas & pastikan settings termuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentCart = ref.read(cartProvider);
      final intVal = currentCart.grandTotal.round();
      _cashController.text =
          NumberFormat.decimalPattern('id_ID').format(intVal);
      if (currentCart.customerName.trim().isNotEmpty) {
        _customerNameController.text = currentCart.customerName.trim();
      }
      final auth = ref.read(authProvider);
      if (auth.storeId.isNotEmpty) {
        ref.read(storeSettingsProvider.notifier).fetchSettings(auth.storeId);
      }
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _cashController.dispose();
    _queueController.dispose();
    super.dispose();
  }

  double get _cashReceived {
    final cleanStr =
        _cashController.text.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(cleanStr) ?? 0.0;
  }

  double get _changeAmount {
    final cart = ref.read(cartProvider);
    return _cashReceived - cart.grandTotal;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  List<int> _getSuggestedCashAmounts(double total) {
    final numTotal = total.round();
    if (numTotal <= 0) return [10000, 20000, 50000, 100000];

    final suggestions = <int>{};
    const standardNotes = [2000, 5000, 10000, 20000, 50000, 100000];
    for (final note in standardNotes) {
      if (note > numTotal) {
        suggestions.add(note);
      }
    }

    if (numTotal < 100000) {
      final ceil5k = ((numTotal + 4999) ~/ 5000) * 5000;
      if (ceil5k > numTotal) suggestions.add(ceil5k);

      final ceil10k = ((numTotal + 9999) ~/ 10000) * 10000;
      if (ceil10k > numTotal) suggestions.add(ceil10k);

      final ceil20k = ((numTotal + 19999) ~/ 20000) * 20000;
      if (ceil20k > numTotal && ceil20k <= 100000) suggestions.add(ceil20k);

      if (numTotal < 50000) suggestions.add(50000);
      if (numTotal < 100000) suggestions.add(100000);
    } else {
      final ceil10k = ((numTotal + 9999) ~/ 10000) * 10000;
      if (ceil10k > numTotal) suggestions.add(ceil10k);

      final ceil20k = ((numTotal + 19999) ~/ 20000) * 20000;
      if (ceil20k > numTotal) suggestions.add(ceil20k);

      final ceil50k = ((numTotal + 49999) ~/ 50000) * 50000;
      if (ceil50k > numTotal) suggestions.add(ceil50k);

      final ceil100k = ((numTotal + 99999) ~/ 100000) * 100000;
      if (ceil100k > numTotal) {
        suggestions.add(ceil100k);
        suggestions.add(ceil100k + 100000);
      } else {
        suggestions.add(ceil100k + 100000);
      }
    }

    final sorted = suggestions.where((v) => v > numTotal).toList()..sort();
    return sorted.take(4).toList();
  }

  String _formatChipLabel(int amount) {
    if (amount >= 1000 && amount % 1000 == 0) {
      return '${amount ~/ 1000}rb';
    }
    return NumberFormat.decimalPattern('id_ID').format(amount);
  }

  void _showMemberSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (c, modalRef, child) {
          final cs = modalRef.watch(customerProvider);
          return MemberSelectorSheet(
            customers: cs.customers,
            isLoading: cs.isLoading,
            selectedCustomerId: ref.read(cartProvider).customerId,
            onSelectGuest: () {
              ref.read(cartProvider.notifier).setCustomer(null);
              Navigator.pop(ctx);
              AppToast.showInfo(context, 'Beralih ke mode Guest');
            },
            onSelectCustomer: (cust) {
              ref.read(cartProvider.notifier).setCustomer(cust);
              _customerNameController.text = cust.name;
              Navigator.pop(ctx);
              AppToast.showSuccess(
                context,
                'Member "${cust.name}" teridentifikasi!',
              );
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

  void _showCreateMemberDialog({
    String? initName,
    String? initPhone,
    bool focusPhone = false,
  }) {
    final nameCtrl = TextEditingController(text: initName ?? '');
    final phoneCtrl = TextEditingController(text: initPhone ?? '');
    final emailCtrl = TextEditingController();
    final nameFocusNode = FocusNode();
    final phoneFocusNode = FocusNode();
    bool saving = false;

    if (focusPhone ||
        (initName != null &&
            initName.isNotEmpty &&
            (initPhone == null || initPhone.isEmpty))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        phoneFocusNode.requestFocus();
      });
    }

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
              _memberField(nameCtrl, 'Nama Lengkap *', 'Contoh: Budi',
                  cap: TextCapitalization.words, focusNode: nameFocusNode),
              const SizedBox(height: 12),
              _memberField(phoneCtrl, 'Nomor Telepon / WA', '08xxxxxxxxxx',
                  keyboard: TextInputType.phone,
                  focusNode: phoneFocusNode,
                  formatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              _memberField(emailCtrl, 'Email (Opsional)', 'budi@example.com',
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
                        _customerNameController.text = newC.name;
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          HapticFeedback.lightImpact();
                          AppToast.showSuccess(
                              context,
                              'Member baru "${newC.name}" didaftarkan & dipilih!');
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

  Widget _memberField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboard,
    TextCapitalization cap = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    FocusNode? focusNode,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textCapitalization: cap,
        inputFormatters: formatters,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Future<void> _handleProcessPayment() async {
    final cart = ref.read(cartProvider);
    final auth = ref.read(authProvider);
    final shift = ref.read(shiftProvider);

    if (cart.isEmpty) {
      AppToast.showError(context, 'Keranjang belanja kosong.');
      return;
    }

    if (cart.queueInput.trim().isEmpty) {
      AppToast.showError(
        context,
        'Nomor antrean wajib diisi sebelum memproses pembayaran!',
      );
      return;
    }

    if (!shift.hasActiveShift || shift.activeShift == null) {
      AppToast.showError(
        context,
        'Shift kasir belum dibuka! Silakan buka shift di tab Kelola Shift.',
      );
      return;
    }

    if (_paymentMethod == 'CASH' && _cashReceived < cart.grandTotal) {
      AppToast.showError(
        context,
        'Uang tunai yang diterima kurang dari total pembayaran.',
      );
      return;
    }

    setState(() => _isProcessing = true);

    final result = await CheckoutService.processCheckout(
      client: Supabase.instance.client,
      cart: cart,
      storeId: auth.storeId,
      dbUserId: auth.dbUserId,
      shiftId: shift.activeShift!.id,
      paymentMethod: _paymentMethod,
      cashReceived: _paymentMethod == 'CASH' ? _cashReceived : null,
      customerName: _customerNameController.text,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.error != null) {
      AppToast.showError(context, result.error!);
      return;
    }

    final createdOrder = result.order!;

    // Cetak struk otomatis jika dicentang dan printer terhubung
    final printerState = ref.read(printerProvider);
    if (_autoPrintReceipt && printerState.isConnected) {
      ref
          .read(printerProvider.notifier)
          .printReceipt(
            createdOrder,
            storeName: auth.storeName.isNotEmpty
                ? auth.storeName
                : 'SCHAW CAFE',
            cashierName: auth.userName,
            settings: ref.read(storeSettingsProvider).settings,
          );
    }

    // Kosongkan keranjang belanja
    ref.read(cartProvider.notifier).clearCart();

    // Tampilkan dialog sukses transaksi
    _showSuccessDialog(createdOrder);
  }

  void _showSuccessDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pembayaran Berhasil! 🎉',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No. Order: ${order.orderNumber}${order.publicQrToken != null ? " • QR #${order.publicQrToken}" : ""}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Nomor Antrean Menonjol
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'NOMOR ANTREAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.queueNumber ?? '-',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    order.diningLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            if (order.promotionDiscount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(order.productSubtotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.promoCodeSnapshot != null
                        ? 'Diskon Promo (${order.promoCodeSnapshot})'
                        : 'Diskon Promo',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '-${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(order.promotionDiscount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tagihan',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  order.formattedGrandTotal,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Metode Bayar',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  order.payment?.method ?? 'CASH',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (order.payment?.method == 'CASH' &&
                order.payment?.cashReceived != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uang Diterima',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    order.payment!.formattedCashReceived,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (order.payment?.changeAmount != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kembalian',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      order.payment!.formattedChangeAmount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row: Cetak Tiket Dapur & Cetak Struk
              Row(
                children: [
                  // 1. Cetak Tiket Dapur (Sky Blue #0284C7 seperti Web)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final printerState = ref.read(printerProvider);
                        if (!printerState.isConnected) {
                          AppToast.showWarning(
                            context,
                            'Printer belum terhubung. Sambungkan di Pengaturan Printer.',
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
                            'Tiket dapur berhasil dicetak!',
                          );
                        } else {
                          AppToast.showError(
                            context,
                            'Gagal mencetak tiket dapur. Periksa printer.',
                          );
                        }
                      },
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Tiket Dapur',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Cetak Struk (Slate #475569 seperti Web)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF475569),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 11,
                        ),
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
                            'Printer belum terhubung. Sambungkan di Pengaturan Printer.',
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
                              settings: ref
                                  .read(storeSettingsProvider)
                                  .settings,
                            );
                        if (!mounted) return;
                        if (success) {
                          AppToast.showSuccess(
                            context,
                            'Struk berhasil dicetak!',
                          );
                        } else {
                          AppToast.showError(
                            context,
                            'Gagal mencetak struk. Periksa status printer.',
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cetak Struk',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Tombol Transaksi Baru (Emerald Green #059669 penuh seperti Web)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Tutup dialog
                    Navigator.pop(
                      context,
                    ); // Kembali dari checkout screen ke POS
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Transaksi Baru ✓',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final storeSettings = ref.watch(storeSettingsProvider).settings;

    ref.listen<CartState>(cartProvider, (prev, next) {
      if (prev?.queueInput != next.queueInput &&
          _queueController.text != next.queueInput) {
        _queueController.text = next.queueInput;
      }
      if (prev?.customerName != next.customerName &&
          _customerNameController.text != next.customerName) {
        _customerNameController.text = next.customerName;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Ringkasan Pesanan Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL TAGIHAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cart.diningOption.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (cart.hasPromoApplied) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                cart.formattedSubtotal,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Diskon Promo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cart.appliedPromo!.code,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '-${cart.formattedPromotionDiscount}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                        ],
                        Text(
                          cart.formattedGrandTotal,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${cart.totalItems} item menu dipilih',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Info Pelanggan & Member
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: cart.isMemberVerified
                                    ? AppColors.primaryContainer
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                cart.isMemberVerified
                                    ? Icons.stars_rounded
                                    : Icons.person_outline_rounded,
                                size: 16,
                                color: cart.isMemberVerified
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pelanggan & Member',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (cart.isMemberVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Member Aktif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (cart.isMemberVerified) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.stars_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
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
                                      if (cart.customerPhone != null &&
                                          cart.customerPhone!.isNotEmpty)
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    side: BorderSide(
                                      color: AppColors.primary.withValues(alpha: 0.5),
                                    ),
                                    foregroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _showMemberSelector,
                                  child: const Text(
                                    'Ganti',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customerNameController,
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Nama pelanggan (opsional)',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (v) => ref
                                      .read(cartProvider.notifier)
                                      .setCustomerName(v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _showMemberSelector,
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  side: const BorderSide(color: AppColors.primary),
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.person_search_rounded, size: 16),
                                label: const Text(
                                  'Member',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (cart.unregisteredQrPhone != null &&
                            !cart.isMemberVerified) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showCreateMemberDialog(
                              initName: cart.customerName != 'Pelanggan'
                                  ? cart.customerName
                                  : '',
                              initPhone: cart.unregisteredQrPhone,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amberLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: AppColors.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textPrimary,
                                        ),
                                        children: [
                                          const TextSpan(text: 'No. HP '),
                                          TextSpan(
                                            text: cart.unregisteredQrPhone,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const TextSpan(text: ' belum member — '),
                                          const TextSpan(
                                            text: 'Daftarkan?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.amber,
                                              decoration: TextDecoration.underline,
                                            ),
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
                        if (cart.isQrOrderWithoutPhone) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amberLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 15,
                                      color: AppColors.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textPrimary,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Pesanan QR '),
                                            TextSpan(
                                              text: '(${cart.customerName})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' belum terhubung member.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showMemberSelector,
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.2,
                                          ),
                                          foregroundColor: AppColors.primaryDark,
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.person_search_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Cari Member',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showCreateMemberDialog(
                                          initName: cart.customerName != 'Pelanggan'
                                              ? cart.customerName
                                              : '',
                                          focusPhone: true,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.person_add_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          '+ Member Baru',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Input Nomor Antrean (Wajib Diisi)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: cart.queueInput.trim().isEmpty
                          ? AppColors.error.withValues(alpha: 0.6)
                          : AppColors.border,
                      width: cart.queueInput.trim().isEmpty ? 1.4 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: cart.diningOption == DiningOption.dineIn
                                    ? AppColors.primaryContainer
                                    : AppColors.amberLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.confirmation_number_outlined,
                                size: 16,
                                color: cart.diningOption == DiningOption.dineIn
                                    ? AppColors.primaryDark
                                    : AppColors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Nomor Antrean *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cart.diningOption == DiningOption.dineIn
                                    ? AppColors.primaryContainer
                                    : AppColors.amberLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cart.diningOption.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      cart.diningOption == DiningOption.dineIn
                                      ? AppColors.primaryDark
                                      : AppColors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cart.queueInput.trim().isEmpty
                                  ? AppColors.error.withValues(alpha: 0.8)
                                  : AppColors.border,
                              width: cart.queueInput.trim().isEmpty ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Prefix otomatis: A- (Dine-in) atau TA- (Takeaway)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color:
                                      cart.diningOption == DiningOption.takeaway
                                      ? AppColors.amberLight
                                      : AppColors.primaryContainer,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(13),
                                  ),
                                  border: const Border(
                                    right: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${cart.diningOption.shortCode}-',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color:
                                        cart.diningOption ==
                                            DiningOption.takeaway
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
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    fontFamily: 'monospace',
                                    color: cart.queueInput.trim().isEmpty
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Contoh: 01 (Wajib diisi)',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'sans-serif',
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    ref
                                        .read(cartProvider.notifier)
                                        .setQueueInput(val);
                                    setState(() {});
                                  },
                                ),
                              ),
                              if (cart.queueInput.trim().isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    _queueController.clear();
                                    ref
                                        .read(cartProvider.notifier)
                                        .setQueueInput('');
                                    setState(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (cart.queueInput.trim().isEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nomor antrean wajib diisi sebelum pembayaran diproses',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nomor antrean: ${cart.fullQueueNumber} (${cart.diningOption == DiningOption.dineIn ? "Dine-in" : "Takeaway"})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Pilihan Metode Pembayaran
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _paymentMethod = 'CASH';
                                }),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _paymentMethod == 'CASH'
                                        ? AppColors.primaryContainer
                                        : AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _paymentMethod == 'CASH'
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: _paymentMethod == 'CASH' ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.payments_rounded,
                                        size: 18,
                                        color: _paymentMethod == 'CASH'
                                            ? AppColors.primaryDark
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'CASH (Tunai)',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _paymentMethod == 'CASH'
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: _paymentMethod == 'CASH'
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _paymentMethod = 'QRIS';
                                }),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _paymentMethod == 'QRIS'
                                        ? AppColors.primaryContainer
                                        : AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _paymentMethod == 'QRIS'
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: _paymentMethod == 'QRIS' ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.qr_code_scanner_rounded,
                                        size: 18,
                                        color: _paymentMethod == 'QRIS'
                                            ? AppColors.primaryDark
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'QRIS',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _paymentMethod == 'QRIS'
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: _paymentMethod == 'QRIS'
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Input Tambahan untuk CASH
                        if (_paymentMethod == 'CASH') ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Uang Tunai Diterima',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsSeparatorInputFormatter(),
                            ],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                              hintText: '0',
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
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
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              suffixIcon: _cashController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _cashController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Quick Preset Chips (Pecahan Rupiah Mendekati Total)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Uang Pas'),
                                selected: (_cashReceived - cart.grandTotal).abs() < 1 &&
                                    _cashReceived > 0,
                                onSelected: (_) {
                                  setState(() {
                                    final intVal = cart.grandTotal.round();
                                    final formatted = NumberFormat.decimalPattern('id_ID')
                                        .format(intVal);
                                    _cashController.text = formatted;
                                    _cashController.selection =
                                        TextSelection.collapsed(offset: formatted.length);
                                  });
                                },
                                selectedColor: AppColors.primaryContainer,
                                side: BorderSide(
                                  color: (_cashReceived - cart.grandTotal).abs() < 1 &&
                                          _cashReceived > 0
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: (_cashReceived - cart.grandTotal).abs() < 1 &&
                                          _cashReceived > 0
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                              ..._getSuggestedCashAmounts(cart.grandTotal).map((nominal) {
                                final isSelected =
                                    (_cashReceived - nominal).abs() < 1;
                                return ChoiceChip(
                                  label: Text(_formatChipLabel(nominal)),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      final formatted = NumberFormat.decimalPattern('id_ID')
                                          .format(nominal);
                                      _cashController.text = formatted;
                                      _cashController.selection =
                                          TextSelection.collapsed(offset: formatted.length);
                                    });
                                  },
                                  selectedColor: AppColors.primaryContainer,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : AppColors.textPrimary,
                                  ),
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _changeAmount >= 0
                                  ? AppColors.surfaceMuted
                                  : AppColors.roseLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _changeAmount >= 0
                                    ? AppColors.border
                                    : AppColors.rose,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _changeAmount >= 0
                                      ? 'Kembalian'
                                      : 'Uang Kurang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _changeAmount >= 0
                                        ? AppColors.textPrimary
                                        : AppColors.rose,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(_changeAmount.abs()),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _changeAmount >= 0
                                        ? AppColors.primaryDark
                                        : AppColors.rose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildQrisSection(cart, storeSettings),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Checkbox Cetak Struk
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoPrintReceipt,
                  activeColor: AppColors.primary,
                  onChanged: (val) =>
                      setState(() => _autoPrintReceipt = val ?? true),
                  title: const Text(
                    'Cetak struk belanja secara otomatis',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Jika printer thermal Bluetooth telah terhubung',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tombol Proses Pembayaran
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleProcessPayment,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Konfirmasi Pembayaran • ${cart.formattedGrandTotal}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan Barcode QRIS Toko yang diambil dari tabel StoreSettings (kolom qrisImageUrl)
  Widget _buildQrisSection(CartState cart, StoreSettingsModel storeSettings) {
    final qrisUrl = storeSettings.qrisImageUrl?.trim();
    final hasQris = qrisUrl != null && qrisUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasQris ? AppColors.primaryLight : AppColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'QRIS Pembayaran Toko',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cart.formattedGrandTotal,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (hasQris) ...[
            // Card Gambar QRIS
            Center(
              child: GestureDetector(
                onTap: () => _showQrisFullscreenDialog(qrisUrl, cart),
                child: Hero(
                  tag: 'store-qris-image',
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 230,
                      maxWidth: 230,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        qrisUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 200,
                            width: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            width: 180,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.broken_image_rounded,
                                  size: 36,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Gagal memuat barcode QRIS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: () => _showQrisFullscreenDialog(qrisUrl, cart),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.fullscreen_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ketuk gambar untuk perbesar QRIS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Belum ada QRIS di database store setting
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Gambar QRIS belum diunggah di Pengaturan Toko. Kasir dapat menggunakan barcode QRIS fisik di meja.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pastikan dana sebesar ${cart.formattedGrandTotal} sudah terverifikasi masuk ke rekening toko.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog Fullscreen untuk menampilkan barcode QRIS ukuran besar ke pelanggan
  void _showQrisFullscreenDialog(String qrisUrl, CartState cart) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan QRIS Toko',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        qrisUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Tagihan: ${cart.formattedGrandTotal}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tunjukkan kode QR ini ke kamera pelanggan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Selesai Scan / Tutup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formatter untuk memformat input angka dengan pemisah ribuan standar Indonesia (titik)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Batasi maksimum 12 digit (hingga ratusan miliar) agar tidak overflow
    final truncatedDigits = cleanDigits.length > 12
        ? cleanDigits.substring(0, 12)
        : cleanDigits;

    final intVal = int.tryParse(truncatedDigits);
    if (intVal == null) {
      return oldValue;
    }

    final formatted = _formatter.format(intVal);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
