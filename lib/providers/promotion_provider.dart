import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../models/promotion_model.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

@immutable
class PromotionState {
  final List<PromotionModel> promotions;
  final bool isLoading;
  final String? errorMessage;

  const PromotionState({
    this.promotions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PromotionState copyWith({
    List<PromotionModel>? promotions,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return PromotionState(
      promotions: promotions ?? this.promotions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class PromotionNotifier extends Notifier<PromotionState> {
  @override
  PromotionState build() {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && next.storeId != prev?.storeId) {
        fetchActivePromotions(next.storeId);
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.storeId.isNotEmpty) {
      Future.microtask(() => fetchActivePromotions(authState.storeId));
    }

    return const PromotionState();
  }

  /// Ambil daftar seluruh promosi aktif dari Supabase
  Future<void> fetchActivePromotions([String? explicitStoreId]) async {
    final storeId = explicitStoreId ?? ref.read(authProvider).storeId;
    if (storeId.isEmpty) {
      debugPrint('[PromotionNotifier] fetchActivePromotions: storeId is empty');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;

      // Ambil promosi dengan status ACTIVE untuk store ini
      final response = await supaClient
          .from('Promotion')
          .select('''
            *,
            conditionGroup:PromotionConditionGroup(
              *,
              conditions:PromotionCondition(
                *,
                product:Product(id, name, price)
              )
            ),
            discountAction:DiscountAction(*)
          ''')
          .eq('storeId', storeId)
          .eq('status', 'ACTIVE')
          .order('priority', ascending: false)
          .order('createdAt', ascending: false);

      final now = DateTime.now();
      final list = <PromotionModel>[];

      for (final rawItem in (response as List)) {
        if (rawItem is Map) {
          final p = PromotionModel.fromMap(rawItem);
          if (p.id.isNotEmpty) {
            // Validasi tanggal mulai & berakhir secara lokal agar akurat
            if (p.startDate != null && now.isBefore(p.startDate!)) continue;
            if (p.endDate != null && now.isAfter(p.endDate!)) continue;
            // Validasi kuota penggunaan
            if (p.usageLimit != null && p.usageCount >= p.usageLimit!) continue;
            list.add(p);
          }
        }
      }

      state = state.copyWith(
        promotions: list,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e, st) {
      debugPrint('[PromotionNotifier] fetchActivePromotions error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat promosi: ${e.toString()}',
      );
    }
  }

  /// Cari promo aktif berdasarkan kode promo
  PromotionModel? findPromoByCode(String rawCode) {
    final clean = rawCode.trim().toUpperCase();
    if (clean.isEmpty) return null;
    return state.promotions.firstWhere(
      (p) => p.code.trim().toUpperCase() == clean,
      orElse: () => const PromotionModel(
        id: '',
        name: '',
        code: '',
        discountType: 'FIXED',
        discountValue: 0,
      ),
    );
  }

  /// Evaluasi kelayakan promosi terhadap kondisi keranjang saat ini
  static PromoEvaluationResult evaluatePromo(PromotionModel promo, CartState cart) {
    final missingRequirements = <String>[];
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // 1. Cek apakah keranjang masih kosong
    if (cart.isEmpty) {
      missingRequirements.add('Keranjang belanja masih kosong. Tambahkan menu terlebih dahulu.');
    }

    // 2. Cek Batas Kuota Penggunaan
    if (promo.usageLimit != null && promo.usageCount >= promo.usageLimit!) {
      missingRequirements.add('Kuota penggunaan promo ini sudah habis.');
    }

    // 3. Cek Rentang Tanggal Aktif
    final now = DateTime.now();
    if (promo.startDate != null && now.isBefore(promo.startDate!)) {
      missingRequirements.add('Promo belum mulai berlaku.');
    }
    if (promo.endDate != null && now.isAfter(promo.endDate!)) {
      missingRequirements.add('Masa berlaku promo sudah berakhir.');
    }

    // 4. Cek Syarat Minimum Pembelian (MINIMUM_PURCHASE)
    if (promo.minimumPurchase != null && promo.minimumPurchase! > 0) {
      final minReq = promo.minimumPurchase!;
      if (cart.totalPrice < minReq) {
        final shortage = minReq - cart.totalPrice;
        missingRequirements.add(
          'Kurang belanja ${currencyFormatter.format(shortage)} lagi (Minimal belanja ${currencyFormatter.format(minReq)}).',
        );
      }
    }

    // 5. Cek Syarat Target Produk Spesifik (PRODUCT Scope)
    double eligibleSubtotal = cart.totalPrice;
    if (promo.isProductScope && promo.targetProductId != null && promo.targetProductId!.isNotEmpty) {
      final targetItems = cart.items.where((it) => it.productId == promo.targetProductId).toList();
      final targetName = promo.targetProductName ?? 'Menu Spesifik';

      if (targetItems.isEmpty) {
        missingRequirements.add('Wajib menambahkan menu "$targetName" ke dalam keranjang belanja.');
        eligibleSubtotal = 0;
      } else {
        eligibleSubtotal = targetItems.fold(0.0, (sum, it) => sum + it.subtotal);
      }
    }

    // 6. Hitung Estimasi Penghematan Diskon
    final isEligible = missingRequirements.isEmpty;
    double estimatedDiscount = 0;

    if (isEligible && eligibleSubtotal > 0) {
      if (promo.isPercentage) {
        estimatedDiscount = eligibleSubtotal * (promo.discountValue / 100.0);
      } else {
        estimatedDiscount = math.min(eligibleSubtotal, promo.discountValue);
      }

      if (promo.maxDiscount != null && promo.maxDiscount! > 0) {
        if (estimatedDiscount > promo.maxDiscount!) {
          estimatedDiscount = promo.maxDiscount!;
        }
      }

      estimatedDiscount = (estimatedDiscount * 100).round() / 100.0;
      estimatedDiscount = math.min(estimatedDiscount, cart.totalPrice);
    }

    return PromoEvaluationResult(
      isEligible: isEligible,
      missingRequirements: missingRequirements,
      estimatedDiscount: estimatedDiscount,
    );
  }
}

final promotionProvider =
    NotifierProvider<PromotionNotifier, PromotionState>(PromotionNotifier.new);
