import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/customer_model.dart';

/// Modal bottom sheet untuk memilih member terdaftar atau beralih ke mode Guest
class MemberSelectorSheet extends StatefulWidget {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? selectedCustomerId;
  final VoidCallback onSelectGuest;
  final ValueChanged<CustomerModel> onSelectCustomer;
  final VoidCallback onCreateNew;

  const MemberSelectorSheet({
    super.key,
    required this.customers,
    required this.isLoading,
    this.selectedCustomerId,
    required this.onSelectGuest,
    required this.onSelectCustomer,
    required this.onCreateNew,
  });

  @override
  State<MemberSelectorSheet> createState() => _MemberSelectorSheetState();
}

class _MemberSelectorSheetState extends State<MemberSelectorSheet> {
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
