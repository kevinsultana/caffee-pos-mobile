import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ToastType { success, error, info, warning }

/// Toast notifikasi modern yang melayang di bagian ATAS layar (Top Toast)
/// Mencegah toast menutupi tombol-tombol dan bottom navigation di bagian bawah.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;
  static GlobalKey<_ToastWidgetState>? _activeKey;

  /// Tampilkan toast sukses (hijau)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(context, message, type: ToastType.success, duration: duration);
  }

  /// Tampilkan toast error (merah / rose)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(context, message, type: ToastType.error, duration: duration);
  }

  /// Tampilkan toast informasi (biru / netral)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(context, message, type: ToastType.info, duration: duration);
  }

  /// Tampilkan toast peringatan (amber)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(context, message, type: ToastType.warning, duration: duration);
  }

  /// Tampilkan toast custom di bagian atas layar
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2500),
    IconData? customIcon,
  }) {
    debugPrint('[AppToast ${type.name.toUpperCase()}] $message');

    // Tutup toast aktif sebelumnya jika ada
    _dismissImmediately();

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context);
    if (overlay == null) {
      try {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.removeCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  type == ToastType.error
                      ? Icons.error_rounded
                      : type == ToastType.success
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: type == ToastType.error
                ? AppColors.rose
                : type == ToastType.warning
                    ? AppColors.amber
                    : const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            duration: duration,
          ),
        );
      } catch (_) {}
      return;
    }

    final key = GlobalKey<_ToastWidgetState>();
    _activeKey = key;

    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        key: key,
        message: message,
        type: type,
        customIcon: customIcon,
        onDismiss: () => _removeEntry(),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      _activeKey?.currentState?.dismiss();
    });
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _activeKey?.currentState?.dismiss();
  }

  static void _dismissImmediately() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
    _activeKey = null;
  }

  static void _removeEntry() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
    _activeKey = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? customIcon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    super.key,
    required this.message,
    required this.type,
    this.customIcon,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
  }

  Future<void> dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.primary;
      case ToastType.error:
        return AppColors.rose;
      case ToastType.warning:
        return AppColors.amber;
      case ToastType.info:
        return AppColors.blue;
    }
  }

  IconData get _icon {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding =
        mediaQuery.padding.top > 0 ? mediaQuery.padding.top : 24.0;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: dismiss,
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null &&
                    details.primaryDelta! < -4) {
                  dismiss();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), // Dark slate premium
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon,
                        color: _accentColor,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
