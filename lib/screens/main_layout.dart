import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class MainLayout extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Kasir POS';
      case 1:
        return 'Riwayat Transaksi';
      case 2:
        return 'Kelola Shift';
      case 3:
        return 'QR Meja';
      default:
        return 'Schaw Cafe POS';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTitle(currentIndex),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              authState.userName.isNotEmpty
                  ? 'Kasir: ${authState.userName} (${authState.roleName})'
                  : (authState.userEmail.isNotEmpty ? 'Kasir: ${authState.userEmail}' : 'Kasir Aktif'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Printer Bluetooth',
            icon: const Icon(Icons.print_rounded),
            onPressed: () => context.push('/settings/printer'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi Akun',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'account') {
                context.push('/account');
              } else if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar dari akun kasir?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authProvider.notifier).signOut();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'account',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Pengaturan Akun', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Keluar Akun', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'Shift',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2_rounded),
            label: 'QR Meja',
          ),
        ],
      ),
    );
  }
}
