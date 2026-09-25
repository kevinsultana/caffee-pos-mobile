import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

/// Provider signal untuk mentrigger refresh data Riwayat Transaksi saat menu dibuka
final historyRefreshProvider =
    NotifierProvider<TabRefreshNotifier, int>(TabRefreshNotifier.new);

/// Provider signal untuk mentrigger refresh data Shift saat menu dibuka
final shiftRefreshProvider =
    NotifierProvider<TabRefreshNotifier, int>(TabRefreshNotifier.new);
