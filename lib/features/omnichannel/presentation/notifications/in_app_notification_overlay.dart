import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Banner notifikasi in-app gaya WhatsApp.
/// Tampil di bagian atas layar saat ada chat masuk baru ke chatbot.
///
/// Ini adalah implementasi murni Flutter (tanpa package eksternal seperti
/// flutter_local_notifications). Cocok untuk menampilkan notifikasi ketika
/// app sedang aktif/foreground.
class InAppNotificationOverlay {
  InAppNotificationOverlay._();

  static final InAppNotificationOverlay instance = InAppNotificationOverlay._();

  OverlayEntry? _currentEntry;
  Timer? _autoDismissTimer;

  /// Tampilkan banner notifikasi.
  ///
  /// [context] - Context untuk mengakses Overlay
  /// [title] - Judul (biasanya nama pengirim)
  /// [body] - Isi pesan
  /// [avatarLabel] - Inisial untuk avatar (mis. "NC" untuk Nerry Cloudio)
  /// [avatarColors] - Gradient untuk avatar
  /// [onTap] - Callback saat banner di-tap
  /// [duration] - Berapa lama banner tampil sebelum auto-dismiss
  void show({
    required BuildContext context,
    required String title,
    required String body,
    String? avatarLabel,
    List<Color>? avatarColors,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    // Dismiss notifikasi sebelumnya jika masih ada
    _dismiss();

    // Getaran ringan agar terasa natural
    HapticFeedback.lightImpact();

    final entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        title: title,
        body: body,
        avatarLabel: avatarLabel ?? _initialFrom(title),
        avatarColors: avatarColors ?? _colorsFor(title),
        onTap: () {
          _dismiss();
          onTap?.call();
        },
        onDismiss: _dismiss,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _autoDismissTimer = Timer(duration, _dismiss);
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// Tampilkan ringkasan jumlah pesan baru (untuk batch update dari poll).
  void showSummary({
    required BuildContext context,
    required int newMessageCount,
    required String firstSenderName,
    String? firstSenderPreview,
    VoidCallback? onTap,
  }) {
    final title = newMessageCount == 1
        ? firstSenderName
        : '$firstSenderName & ${newMessageCount - 1} lainnya';
    final body =
        (firstSenderPreview != null && firstSenderPreview.trim().isNotEmpty)
        ? firstSenderPreview.trim()
        : 'Pesan baru masuk';

    show(
      context: context,
      title: title,
      body: body,
      avatarLabel: _initialFrom(firstSenderName),
      avatarColors: _colorsFor(firstSenderName),
      onTap: onTap,
    );
  }

  static String _initialFrom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'C';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  static List<Color> _colorsFor(String name) {
    final seed = name.isEmpty ? 0 : name.codeUnitAt(0);
    switch (seed % 5) {
      case 0:
        return const <Color>[Color(0xFF02A78F), Color(0xFF18C4A7)];
      case 1:
        return const <Color>[Color(0xFF7E57C2), Color(0xFFB06BFF)];
      case 2:
        return const <Color>[Color(0xFF5C6BC0), Color(0xFF7986CB)];
      case 3:
        return const <Color>[Color(0xFF8D6E63), Color(0xFFB1897E)];
      default:
        return const <Color>[Color(0xFF607D8B), Color(0xFF78909C)];
    }
  }
}

class _NotificationBanner extends StatefulWidget {
  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.avatarLabel,
    required this.avatarColors,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String avatarLabel;
  final List<Color> avatarColors;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dy;
                if (_dragOffset > 0) _dragOffset = 0;
              });
            },
            onVerticalDragEnd: (_) {
              if (_dragOffset < -40) {
                _handleDismiss();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            onTap: () {
              _controller.reverse();
              widget.onTap();
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x29000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.avatarColors,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.avatarLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF02A78F),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF555555),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleDismiss,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF999999),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
