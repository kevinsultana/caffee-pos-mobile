import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/cash_movement_model.dart';
import '../../models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shiftProvider.notifier).checkActiveShift();
    });
  }

  // ─────────────────────────────────────────────
  // DIALOG: BUKA SHIFT
  // ─────────────────────────────────────────────
  Future<void> _showOpenShiftDialog() async {
    final cashController = TextEditingController(text: '100000');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              scrollable: true,
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
                  const Text('Buka Shift Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan jumlah uang kas modal awal di dalam laci kasir:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cashController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Modal Awal (Rp)',
                        prefixText: 'Rp ',
                        hintText: '100000',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Modal awal wajib diisi';
                        final amount = double.tryParse(val);
                        if (amount == null || amount < 0) return 'Masukkan nominal yang valid';
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
                          onPressed: () => setDialogState(() => cashController.text = nominal.toString()),
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
                    if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  child: const Text('Buka Shift'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(cashController.text) ?? 0.0;
    final error = await ref.read(shiftProvider.notifier).openShift(openingCash: amount);

    if (!mounted) return;

    if (error != null) {
      AppToast.showError(context, error);
    } else {
      AppToast.showSuccess(context, 'Shift berhasil dibuka! Selamat bertugas.');
    }
  }

  // ─────────────────────────────────────────────
  // DIALOG: TUTUP SHIFT (komprehensif dengan rekapan)
  // ─────────────────────────────────────────────
  Future<void> _showCloseShiftDialog(ShiftModel shift) async {
    final summary = ref.read(shiftProvider).summary;
    final actualCashController = TextEditingController(
      text: summary.expectedCash.toStringAsFixed(0),
    );
    final depositedCashController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Hitung selisih secara realtime dari input user
            double currentActual = double.tryParse(actualCashController.text) ?? 0.0;
            double difference = currentActual - summary.expectedCash;
            bool isShortfall = difference < 0;

            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.roseLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_clock_rounded, color: AppColors.rose, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tutup Shift',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── REKAP SHIFT ──────────────────────────────
                      _buildSectionLabel('Rekapan Shift'),
                      const SizedBox(height: 8),
                      _buildSummaryCard(summary, shift),
                      const SizedBox(height: 20),

                      // ── INPUT UANG FISIK AKTUAL ───────────────────
                      _buildSectionLabel('Hitung Uang Fisik di Laci'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: actualCashController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Uang Fisik Aktual (Rp)',
                          prefixText: 'Rp ',
                          hintText: '0',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                          if ((double.tryParse(val) ?? -1) < 0) return 'Nominal tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── INPUT DISETOR KE OWNER ─────────────────────
                      TextFormField(
                        controller: depositedCashController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Uang Disetor ke Owner (Rp)',
                          prefixText: 'Rp ',
                          hintText: '0',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null; // opsional
                          if ((double.tryParse(val) ?? -1) < 0) return 'Nominal tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── SELISIH REALTIME ──────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isShortfall ? AppColors.roseLight : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isShortfall
                                ? AppColors.rose.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isShortfall ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                                  size: 18,
                                  color: isShortfall ? AppColors.rose : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isShortfall ? 'Kekurangan' : 'Kelebihan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isShortfall ? AppColors.rose : AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _currencyFmt.format(difference.abs()),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isShortfall ? AppColors.rose : AppColors.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);

                    final actualCash = double.tryParse(actualCashController.text) ?? 0.0;
                    final depositedCash = double.tryParse(depositedCashController.text) ?? 0.0;

                    final error = await ref.read(shiftProvider.notifier).closeShift(
                          actualCash: actualCash,
                          depositedCash: depositedCash,
                        );

                    if (!mounted) return;
                    if (error != null) {
                      AppToast.showError(context, error);
                    } else {
                      AppToast.showSuccess(context, 'Shift berhasil ditutup. Terima kasih!');
                    }
                  },
                  child: const Text('Tutup Shift Sekarang'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // DIALOG: KAS MASUK / KAS KELUAR
  // ─────────────────────────────────────────────
  Future<void> _showCashMovementDialog(CashMovementType type) async {
    final nominalController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final isCashIn = type == CashMovementType.cashIn;
    final color = isCashIn ? AppColors.primary : AppColors.rose;
    final lightColor = isCashIn ? AppColors.primaryContainer : AppColors.roseLight;
    final icon = isCashIn ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded;
    final label = isCashIn ? 'Kas Masuk' : 'Kas Keluar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCashIn
                      ? 'Catat uang tunai yang masuk ke laci kasir di luar transaksi penjualan.'
                      : 'Catat uang tunai yang keluar dari laci kasir (misal: beli bahan baku).',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nominalController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nominal (Rp)',
                    prefixText: 'Rp ',
                    hintText: '50000',
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: color, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi';
                    final amount = double.tryParse(val);
                    if (amount == null || amount <= 0) return 'Masukkan nominal lebih dari 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    hintText: 'Contoh: Beli es batu, Titipan, dll.',
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Keterangan wajib diisi';
                    return null;
                  },
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
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text('Simpan $label'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(nominalController.text) ?? 0.0;
    final reason = reasonController.text.trim();

    final error = await ref.read(shiftProvider.notifier).addCashMovement(
          type: type.value,
          amount: amount,
          reason: reason,
        );

    if (!mounted) return;
    if (error != null) {
      AppToast.showError(context, error);
    } else {
      AppToast.showSuccess(
        context,
        '${isCashIn ? "Kas masuk" : "Kas keluar"} ${_currencyFmt.format(amount)} berhasil dicatat.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(shiftProvider.notifier).checkActiveShift(),
        child: shiftState.isLoading && shiftState.activeShift == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: shiftState.hasActiveShift
                        ? _buildActiveShiftView(context, shiftState, authState)
                        : shiftState.isBlockedByOtherShift
                            ? _buildBlockedShiftView(context, shiftState, authState)
                            : _buildEmptyShiftView(context, authState, shiftState),
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // KONDISI 1: SHIFT DIBLOKIR
  // ─────────────────────────────────────────────
  Widget _buildBlockedShiftView(BuildContext context, ShiftState shiftState, AuthState authState) {
    final activeOther = shiftState.otherActiveShifts.isNotEmpty ? shiftState.otherActiveShifts.first : null;

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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.roseLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_clock_rounded, size: 44, color: AppColors.rose),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.roseLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Batas Shift Toko Penuh (${shiftState.maxActiveShifts}/${shiftState.maxActiveShifts})',
                style: const TextStyle(
                  fontSize: 12,
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Halo ${authState.userName}, akun Anda belum dapat membuka sesi shift baru karena toko sedang memiliki shift aktif.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),

            if (activeOther != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _infoRow('Kasir Bertugas:', activeOther.userName),
                    const SizedBox(height: 8),
                    _infoRow('Dibuka Sejak:', activeOther.formattedOpenedAt),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Text(
              'Berdasarkan pengaturan toko (Store Settings), maksimal shift aktif bersamaan adalah ${shiftState.maxActiveShifts}. Hubungi kasir di atas untuk menutup shift-nya, atau hubungi Owner untuk menambah batas shift toko jika ingin kasir paralel.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => ref.read(shiftProvider.notifier).checkActiveShift(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Cek Ulang Status Shift', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // KONDISI 2: BELUM BUKA SHIFT
  // ─────────────────────────────────────────────
  Widget _buildEmptyShiftView(BuildContext context, AuthState authState, ShiftState shiftState) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.schedule_rounded, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (shiftState.otherActiveShifts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Multi-Shift Aktif (${shiftState.totalStoreOpenShifts}/${shiftState.maxActiveShifts} Slot)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Belum Ada Shift Berjalan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Anda Belum Membuka Shift',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Halo ${authState.userName}, silakan buka shift dan masukkan modal awal di laci kasir sebelum melayani pemesanan pelanggan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.storeName.isNotEmpty ? authState.storeName : 'Schaw Cafe',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Kasir: ${authState.userName} (${authState.roleName})',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showOpenShiftDialog,
                icon: const Icon(Icons.lock_open_rounded, size: 20),
                label: const Text(
                  'Buka Shift Kasir Sekarang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // KONDISI 3: SHIFT AKTIF
  // ─────────────────────────────────────────────
  Widget _buildActiveShiftView(BuildContext context, ShiftState shiftState, AuthState authState) {
    final shift = shiftState.activeShift!;
    final summary = shiftState.summary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── KARTU UTAMA STATUS SHIFT ──────────────────
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Shift Sedang Berjalan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'AKTIF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Kasir: ${shift.userName ?? authState.userName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Toko: ${authState.storeName.isNotEmpty ? authState.storeName : "Schaw Cafe"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // ── RINGKASAN KEUANGAN SHIFT ──────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: shiftState.isSummaryLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          children: [
                            _summaryRow('Modal Kas Awal', summary.openingCash),
                            const Divider(height: 16),
                            _summaryRow('Penjualan Tunai (Cash)', summary.totalCashRevenue, color: AppColors.primary),
                            if (summary.totalNonCashRevenue > 0) ...[
                              const SizedBox(height: 4),
                              _summaryRow('Penjualan Non-Tunai (QRIS)', summary.totalNonCashRevenue,
                                  color: AppColors.blue, note: '(tidak masuk laci)'),
                            ],
                            if (summary.totalCashIn > 0) ...[
                              const SizedBox(height: 4),
                              _summaryRow('+ Kas Masuk', summary.totalCashIn, color: AppColors.primary),
                            ],
                            if (summary.totalCashOut > 0) ...[
                              const SizedBox(height: 4),
                              _summaryRow('− Kas Keluar', summary.totalCashOut, color: AppColors.rose),
                            ],
                            const Divider(height: 16),
                            _summaryRow(
                              'Expected Cash',
                              summary.expectedCash,
                              isBold: true,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(height: 6),
                            _infoRow('Waktu Buka:', shift.formattedOpenedAt),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // ── TOMBOL KAS MASUK / KAS KELUAR ────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCashMovementDialog(CashMovementType.cashIn),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Kas Masuk', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCashMovementDialog(CashMovementType.cashOut),
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                        label: const Text('Kas Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rose,
                          side: const BorderSide(color: AppColors.rose),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── TOMBOL TUTUP SHIFT ──────────────────────
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showCloseShiftDialog(shift),
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text(
                      'Tutup Shift Kasir',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RIWAYAT MUTASI KAS (jika ada) ─────────────
        if (summary.movements.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMovementsCard(summary.movements),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSummaryCard(ShiftSummary summary, ShiftModel shift) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _summaryRow('Modal Awal', summary.openingCash),
          const Divider(height: 14),
          _summaryRow('Penjualan Tunai', summary.totalCashRevenue, color: AppColors.primary),
          if (summary.totalNonCashRevenue > 0) ...[
            const SizedBox(height: 4),
            _summaryRow('Non-Tunai (QRIS)', summary.totalNonCashRevenue, color: AppColors.blue),
          ],
          if (summary.totalCashIn > 0) ...[
            const SizedBox(height: 4),
            _summaryRow('+ Kas Masuk', summary.totalCashIn, color: AppColors.primary),
          ],
          if (summary.totalCashOut > 0) ...[
            const SizedBox(height: 4),
            _summaryRow('− Kas Keluar', summary.totalCashOut, color: AppColors.rose),
          ],
          const Divider(height: 14),
          _summaryRow('Expected Cash', summary.expectedCash, isBold: true, color: AppColors.primaryDark),
        ],
      ),
    );
  }

  Widget _buildMovementsCard(List<CashMovementModel> movements) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Mutasi Kas Shift Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${movements.length} transaksi',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...movements.take(8).map((m) => _buildMovementTile(m)),
            if (movements.length > 8) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '... dan ${movements.length - 8} mutasi lainnya',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMovementTile(CashMovementModel m) {
    final isCashIn = m.isCashIn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isCashIn ? AppColors.primaryContainer : AppColors.roseLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCashIn ? Icons.add_rounded : Icons.remove_rounded,
              size: 14,
              color: isCashIn ? AppColors.primary : AppColors.rose,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.reason,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  m.formattedTime,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${isCashIn ? "+" : "−"} ${m.formattedAmount}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isCashIn ? AppColors.primary : AppColors.rose,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false, Color? color, String? note}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (note != null)
                Text(note, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
        Text(
          _currencyFmt.format(value),
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
