import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../models/promotion_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/promotion_provider.dart';

class PromoSheet extends ConsumerStatefulWidget {
  const PromoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PromoSheet(),
    );
  }

  @override
  ConsumerState<PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends ConsumerState<PromoSheet> {
  final TextEditingController _codeController = TextEditingController();
  int _selectedFilterIndex = 0; // 0: Semua, 1: Bisa Dipakai, 2: Belum Cukup Syarat

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _applyPromo(PromotionModel promo, PromoEvaluationResult eval) {
    if (!eval.isEligible) {
      final reason = eval.missingRequirements.isNotEmpty
          ? eval.missingRequirements.first
          : 'Keranjang belum memenuhi syarat promo ini.';
      AppToast.showWarning(context, reason);
      return;
    }

    ref.read(cartProvider.notifier).applyPromo(promo);
    Navigator.pop(context);
    AppToast.showSuccess(
      context,
      'Promo "${promo.code}" berhasil diterapkan! Hemat ${eval.formattedEstimatedDiscount}',
    );
  }

  void _applyManualCode() {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      AppToast.showError(context, 'Masukkan kode promo terlebih dahulu');
      return;
    }

    final found = ref.read(promotionProvider.notifier).findPromoByCode(raw);
    if (found == null || found.id.isEmpty) {
      AppToast.showError(context, 'Kode promo "$raw" tidak ditemukan atau sudah tidak aktif.');
      return;
    }

    final cart = ref.read(cartProvider);
    final eval = PromotionNotifier.evaluatePromo(found, cart);
    _applyPromo(found, eval);
  }

  @override
  Widget build(BuildContext context) {
    final promoState = ref.watch(promotionProvider);
    final cart = ref.watch(cartProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Evaluasi semua promosi yang tersedia
    final evaluatedList = promoState.promotions.map((promo) {
      final eval = PromotionNotifier.evaluatePromo(promo, cart);
      final isCurrentlyApplied = cart.appliedPromo?.id == promo.id;
      return (promo: promo, eval: eval, isApplied: isCurrentlyApplied);
    }).toList();

    final eligibleList = evaluatedList.where((item) => item.eval.isEligible).toList();
    final ineligibleList = evaluatedList.where((item) => !item.eval.isEligible).toList();

    List<({PromotionModel promo, PromoEvaluationResult eval, bool isApplied})> displayedList;
    if (_selectedFilterIndex == 1) {
      displayedList = eligibleList;
    } else if (_selectedFilterIndex == 2) {
      displayedList = ineligibleList;
    } else {
      displayedList = evaluatedList;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header Modal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.discount_rounded,
                      color: AppColors.primaryDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promo & Voucher Diskon',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Pilih voucher untuk potongan harga otomatis',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Banner Promo Terpasang (jika ada)
            if (cart.appliedPromo != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryLight, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryDark, size: 22),
                    const SizedBox(width: 10),
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
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AKTIF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Potongan: -${cart.formattedPromotionDiscount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ref.read(cartProvider.notifier).removePromo();
                        AppToast.showInfo(context, 'Promo diskon dilepas dari keranjang');
                      },
                      child: const Text(
                        'Batalkan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Form Input Kode Promo Manual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Masukkan kode promo...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _applyManualCode,
                      child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Filter Tabs: [Semua], [Bisa Dipakai], [Belum Cukup Syarat]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildFilterTab(
                      index: 0,
                      label: 'Semua',
                      count: evaluatedList.length,
                    ),
                    _buildFilterTab(
                      index: 1,
                      label: 'Bisa Dipakai',
                      count: eligibleList.length,
                      badgeColor: AppColors.primary,
                    ),
                    _buildFilterTab(
                      index: 2,
                      label: 'Belum Cukup',
                      count: ineligibleList.length,
                      badgeColor: AppColors.amber,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),

            // Daftar List Promo
            Expanded(
              child: promoState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayedList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sentiment_dissatisfied_rounded, size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedFilterIndex == 1
                                      ? 'Belum ada promo yang memenuhi syarat saat ini.'
                                      : _selectedFilterIndex == 2
                                          ? 'Tidak ada promo yang kekurangan syarat.'
                                          : 'Belum ada promo aktif di toko ini.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: displayedList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final item = displayedList[idx];
                            return _buildPromoCard(
                              promo: item.promo,
                              eval: item.eval,
                              isApplied: item.isApplied,
                              currencyFormatter: currencyFormatter,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required int count,
    Color? badgeColor,
  }) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (badgeColor?.withValues(alpha: 0.15) ?? AppColors.surfaceMuted)
                      : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (badgeColor ?? AppColors.textPrimary)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard({
    required PromotionModel promo,
    required PromoEvaluationResult eval,
    required bool isApplied,
    required NumberFormat currencyFormatter,
  }) {
    final isEligible = eval.isEligible;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApplied
              ? AppColors.primary
              : isEligible
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
          width: isApplied ? 2 : 1,
        ),
        boxShadow: isEligible
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Badge Diskon & Status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEligible ? AppColors.primaryLight : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    promo.formattedDiscountBadge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isEligible ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (promo.formattedMaxDiscount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    promo.formattedMaxDiscount!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                if (isApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TERPASANG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (isEligible)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Hemat ${eval.formattedEstimatedDiscount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Judul Promo & Kode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              promo.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (promo.formattedMinPurchase != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              promo.formattedMinPurchase!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (promo.description != null && promo.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                promo.description!,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
              ),
            ),

          // Pesan Syarat yang Belum Terpenuhi (Upselling Tips Kasir)
          if (!isEligible && eval.missingRequirements.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: eval.missingRequirements.map((req) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),

          // Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (promo.targetProductName != null)
                  Expanded(
                    child: Text(
                      'Khusus Menu: ${promo.targetProductName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  const Spacer(),
                if (isApplied)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      ref.read(cartProvider.notifier).removePromo();
                      AppToast.showInfo(context, 'Promo dilepas');
                    },
                    child: const Text('Batalkan Penggunaan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEligible ? AppColors.primary : AppColors.surfaceMuted,
                      foregroundColor: isEligible ? Colors.white : AppColors.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _applyPromo(promo, eval),
                    child: Text(
                      isEligible ? 'Gunakan Promo' : 'Belum Cukup Syarat',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
