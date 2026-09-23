import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/checkout_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _customerNameController = TextEditingController(text: 'Pelanggan');
  final _cashController = TextEditingController();
  String _paymentMethod = 'CASH'; // 'CASH' or 'QRIS'
  bool _autoPrintReceipt = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Default isi uang tunai dengan nominal pas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = ref.read(cartProvider);
      _cashController.text = cart.totalPrice.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  double get _cashReceived => double.tryParse(_cashController.text) ?? 0.0;

  double get _changeAmount {
    final cart = ref.read(cartProvider);
    return _cashReceived - cart.totalPrice;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _handleProcessPayment() async {
    final cart = ref.read(cartProvider);
    final auth = ref.read(authProvider);
    final shift = ref.read(shiftProvider);

    if (cart.isEmpty) {
      AppToast.showError(context, 'Keranjang belanja kosong.');
      return;
    }

    if (!shift.hasActiveShift || shift.activeShift == null) {
      AppToast.showError(
        context,
        'Shift kasir belum dibuka! Silakan buka shift di tab Kelola Shift.',
      );
      return;
    }

    if (_paymentMethod == 'CASH' && _cashReceived < cart.totalPrice) {
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
      ref.read(printerProvider.notifier).printReceipt(
            createdOrder,
            storeName: auth.storeName.isNotEmpty ? auth.storeName : 'SCHAW CAFE',
            cashierName: auth.userName,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pembayaran Berhasil!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No. Order: ${order.orderNumber}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Nomor Antrean Menonjol
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                    const SizedBox(height: 4),
                    Text(
                      order.queueNumber ?? '-',
                      style: const TextStyle(
                        fontSize: 32,
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

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    order.formattedGrandTotal,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (order.payment?.method == 'CASH' && order.payment?.changeAmount != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onPressed: () {
                    final auth = ref.read(authProvider);
                    ref.read(printerProvider.notifier).printReceipt(
                          order,
                          storeName: auth.storeName.isNotEmpty ? auth.storeName : 'SCHAW CAFE',
                          cashierName: auth.userName,
                        );
                    AppToast.showInfo(
                      context,
                      'Perintah cetak struk dikirim ke printer',
                      duration: const Duration(seconds: 1),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Cetak Struk'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Tutup dialog
                    Navigator.pop(context); // Kembali dari checkout screen ke POS
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Selesai'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout Pembayaran'),
      ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        Text(
                          cart.formattedTotalPrice,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${cart.totalItems} item menu dipilih',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Info Nama Pelanggan
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
                          'Nama Pelanggan (Opsional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            hintText: 'Nama pemesan',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Pilihan Metode Pembayaran
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                selected: _paymentMethod == 'CASH',
                                onSelected: (_) => setState(() {
                                  _paymentMethod = 'CASH';
                                }),
                                label: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.money_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('CASH (Tunai)'),
                                  ],
                                ),
                                selectedColor: AppColors.primaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: _paymentMethod == 'CASH' ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                selected: _paymentMethod == 'QRIS',
                                onSelected: (_) => setState(() {
                                  _paymentMethod = 'QRIS';
                                }),
                                label: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_scanner_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('QRIS'),
                                  ],
                                ),
                                selectedColor: AppColors.primaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.border,
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
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              hintText: '0',
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Quick Preset Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Uang Pas'),
                                onPressed: () {
                                  setState(() {
                                    _cashController.text = cart.totalPrice.toStringAsFixed(0);
                                  });
                                },
                              ),
                              ...[50000, 100000, 200000, 500000].map((nominal) {
                                return ActionChip(
                                  label: Text(_formatCurrency(nominal.toDouble())),
                                  onPressed: () {
                                    setState(() {
                                      _cashController.text = nominal.toString();
                                    });
                                  },
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _changeAmount >= 0 ? AppColors.surfaceMuted : AppColors.roseLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _changeAmount >= 0 ? AppColors.border : AppColors.rose,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _changeAmount >= 0 ? 'Kembalian' : 'Uang Kurang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _changeAmount >= 0 ? AppColors.textPrimary : AppColors.rose,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(_changeAmount.abs()),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _changeAmount >= 0 ? AppColors.primaryDark : AppColors.rose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Tampilan Info QRIS
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 40, color: AppColors.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Scan QRIS Toko',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Pastikan pelanggan telah melakukan transfer sebesar ${cart.formattedTotalPrice}.',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
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

                // Checkbox Cetak Struk
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoPrintReceipt,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _autoPrintReceipt = val ?? true),
                  title: const Text(
                    'Cetak struk belanja secara otomatis',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Jika printer thermal Bluetooth telah terhubung',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Selesaikan Pembayaran • ${cart.formattedTotalPrice}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
