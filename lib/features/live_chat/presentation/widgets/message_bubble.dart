import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/chat_message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.timeLabel,
    required this.maxWidth,
    this.onRetry,
    this.onOpenLocation,
  });

  final ChatMessageModel message;
  final String timeLabel;
  final double maxWidth;
  final VoidCallback? onRetry;

  /// Callback when the user taps a location card. If null, the bubble falls
  /// back to copying the coordinates to the clipboard so the admin can still
  /// open them in any map app manually (no external URL launcher dependency).
  final void Function(ChatMessageLocation location)? onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isMine;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _buildBubbleBody(context, isOutgoing),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bubble dispatcher — picks the right layout based on message type.
  // ---------------------------------------------------------------------------

  Widget _buildBubbleBody(BuildContext context, bool isOutgoing) {
    if (message.isLocation) {
      return _LocationBubble(
        message: message,
        isOutgoing: isOutgoing,
        timeLabel: timeLabel,
        onRetry: onRetry,
        onOpenLocation: onOpenLocation,
      );
    }

    if (message.isInteractive) {
      return _InteractiveBubble(
        message: message,
        isOutgoing: isOutgoing,
        timeLabel: timeLabel,
        onRetry: onRetry,
      );
    }

    return _TextBubble(
      message: message,
      isOutgoing: isOutgoing,
      timeLabel: timeLabel,
      onRetry: onRetry,
    );
  }
}

// =============================================================================
// Shared bubble chrome
// =============================================================================

BoxDecoration _bubbleDecoration({required bool isOutgoing}) {
  return BoxDecoration(
    gradient: isOutgoing
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.primary, AppColors.primary700],
          )
        : null,
    color: isOutgoing ? null : AppColors.surfaceTertiary,
    borderRadius: isOutgoing
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
    border: isOutgoing
        ? null
        : Border.all(color: AppColors.borderLight.withValues(alpha: 0.5)),
    boxShadow: <BoxShadow>[
      if (isOutgoing)
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.20),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      BoxShadow(
        color: const Color(0x20000000),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

Widget _buildMetaRow({
  required ChatMessageModel message,
  required bool isOutgoing,
  required String timeLabel,
  required VoidCallback? onRetry,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        timeLabel,
        style: TextStyle(
          fontSize: 11,
          color: isOutgoing
              ? AppColors.white.withValues(alpha: 0.60)
              : AppColors.neutral300,
        ),
      ),
      if (isOutgoing) ...<Widget>[
        const SizedBox(width: 4),
        _PremiumStatusIcon(message: message, onRetry: onRetry),
      ],
    ],
  );
}

// =============================================================================
// Plain text bubble (original behavior, unchanged rendering)
// =============================================================================

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.isOutgoing,
    required this.timeLabel,
    required this.onRetry,
  });

  final ChatMessageModel message;
  final bool isOutgoing;
  final String timeLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _bubbleDecoration(isOutgoing: isOutgoing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            message.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: isOutgoing ? AppColors.white : AppColors.neutral800,
            ),
          ),
          const SizedBox(height: 4),
          _buildMetaRow(
            message: message,
            isOutgoing: isOutgoing,
            timeLabel: timeLabel,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Location bubble — static map preview + place label + copy coords fallback
// =============================================================================

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({
    required this.message,
    required this.isOutgoing,
    required this.timeLabel,
    required this.onRetry,
    required this.onOpenLocation,
  });

  final ChatMessageModel message;
  final bool isOutgoing;
  final String timeLabel;
  final VoidCallback? onRetry;
  final void Function(ChatMessageLocation location)? onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final loc = message.location!;
    final primaryLabel = (loc.name != null && loc.name!.isNotEmpty)
        ? loc.name!
        : (message.text.isNotEmpty ? message.text : 'Lokasi');
    final secondaryLabel = loc.address;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _bubbleDecoration(isOutgoing: isOutgoing),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Tappable map preview
          InkWell(
            onTap: () => _handleTap(context, loc),
            child: _MapPreview(
              latitude: loc.latitude,
              longitude: loc.longitude,
              isOutgoing: isOutgoing,
            ),
          ),

          // Label + meta row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: isOutgoing ? AppColors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        primaryLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: isOutgoing
                              ? AppColors.white
                              : AppColors.neutral800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (secondaryLabel != null && secondaryLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      secondaryLabel,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isOutgoing
                            ? AppColors.white.withValues(alpha: 0.85)
                            : AppColors.neutral700,
                      ),
                    ),
                  ),
                ],
                if (loc.hasCoordinates) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      _formatCoords(loc),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.2,
                        color: isOutgoing
                            ? AppColors.white.withValues(alpha: 0.60)
                            : AppColors.neutral500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildMetaRow(
                    message: message,
                    isOutgoing: isOutgoing,
                    timeLabel: timeLabel,
                    onRetry: onRetry,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, ChatMessageLocation loc) {
    if (onOpenLocation != null) {
      onOpenLocation!(loc);
      return;
    }
    // Fallback: copy coordinates so admin can paste into any map app.
    if (!loc.hasCoordinates) return;
    final text = '${loc.latitude},${loc.longitude}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Koordinat disalin: $text'),
      ),
    );
  }

  String _formatCoords(ChatMessageLocation loc) {
    final lat = loc.latitude!.toStringAsFixed(5);
    final lng = loc.longitude!.toStringAsFixed(5);
    return '$lat, $lng';
  }
}

/// Lightweight map preview. We don't ship a map SDK here; instead we draw a
/// stylized placeholder with a pin. The pin's position reflects the
/// fractional part of the coords so two different locations look visually
/// distinct in the chat list.
class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.isOutgoing,
  });

  final double? latitude;
  final double? longitude;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    // Derive a stable pseudo-position from coords so the pin is
    // deterministic per-location. Fallback to center if no coords.
    double pinX = 0.5;
    double pinY = 0.5;
    if (latitude != null && longitude != null) {
      final fracLat = (latitude! - latitude!.truncateToDouble()).abs();
      final fracLng = (longitude! - longitude!.truncateToDouble()).abs();
      pinX = 0.25 + (fracLng * 0.5).clamp(0.0, 0.5);
      pinY = 0.25 + (fracLat * 0.5).clamp(0.0, 0.5);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Base map color
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.primary50.withValues(alpha: 0.25),
                  AppColors.surfaceSecondary,
                ],
              ),
            ),
          ),
          // Faux street grid
          CustomPaint(
            painter: _MapGridPainter(
              lineColor: AppColors.borderLight.withValues(alpha: 0.9),
              roadColor: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          // Pin
          Align(
            alignment: Alignment(pinX * 2 - 1, pinY * 2 - 1),
            child: Icon(
              Icons.location_pin,
              size: 36,
              color: AppColors.error,
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          // "Tap to open" hint
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Buka peta',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.lineColor, required this.roadColor});

  final Color lineColor;
  final Color roadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final road = Paint()
      ..color = roadColor
      ..strokeWidth = 3;

    // Grid lines
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A couple of "main roads" at fixed offsets
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(_MapGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.roadColor != roadColor;
}

// =============================================================================
// Interactive bubble — renders WhatsApp button/list messages as read-only
// =============================================================================

class _InteractiveBubble extends StatelessWidget {
  const _InteractiveBubble({
    required this.message,
    required this.isOutgoing,
    required this.timeLabel,
    required this.onRetry,
  });

  final ChatMessageModel message;
  final bool isOutgoing;
  final String timeLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final inter = message.interactive!;
    final selectedTitle = _selectedTitle(inter);
    final isList = inter.listOptions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: _bubbleDecoration(isOutgoing: isOutgoing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          if (inter.header != null && inter.header!.isNotEmpty) ...[
            Text(
              inter.header!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: isOutgoing ? AppColors.white : AppColors.neutral800,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Body
          if (inter.body != null && inter.body!.isNotEmpty) ...[
            Text(
              inter.body!,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isOutgoing
                    ? AppColors.white.withValues(alpha: 0.95)
                    : AppColors.neutral800,
              ),
            ),
            const SizedBox(height: 6),
          ] else if ((inter.header == null || inter.header!.isEmpty) &&
              message.text.isNotEmpty) ...[
            // Fallback: show raw text when neither header nor body is present.
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isOutgoing
                    ? AppColors.white.withValues(alpha: 0.95)
                    : AppColors.neutral800,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Footer
          if (inter.footer != null && inter.footer!.isNotEmpty) ...[
            Text(
              inter.footer!,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: isOutgoing
                    ? AppColors.white.withValues(alpha: 0.65)
                    : AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 4),

          // Divider
          Container(
            height: 1,
            color: isOutgoing
                ? AppColors.white.withValues(alpha: 0.20)
                : AppColors.borderLight.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),

          // Options
          if (isList)
            _InteractiveListOptions(
              listButtonTitle: inter.listButtonTitle,
              options: inter.listOptions,
              selectedTitle: selectedTitle,
              isOutgoing: isOutgoing,
            )
          else if (inter.buttonOptions.isNotEmpty)
            _InteractiveButtonOptions(
              options: inter.buttonOptions,
              selectedTitle: selectedTitle,
              isOutgoing: isOutgoing,
            )
          else
            Text(
              'Menu interaktif',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isOutgoing
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.neutral500,
              ),
            ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _buildMetaRow(
              message: message,
              isOutgoing: isOutgoing,
              timeLabel: timeLabel,
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }

  String? _selectedTitle(ChatMessageInteractive inter) {
    final sel = inter.selection;
    if (sel == null) return null;
    // Backend may surface selection under a few shapes; try the common ones.
    final title =
        sel['title'] ??
        sel['selected_title'] ??
        (sel['button_reply'] is Map
            ? (sel['button_reply'] as Map)['title']
            : null) ??
        (sel['list_reply'] is Map ? (sel['list_reply'] as Map)['title'] : null);
    if (title is String && title.trim().isNotEmpty) return title.trim();
    return null;
  }
}

class _InteractiveButtonOptions extends StatelessWidget {
  const _InteractiveButtonOptions({
    required this.options,
    required this.selectedTitle,
    required this.isOutgoing,
  });

  final List<String> options;
  final String? selectedTitle;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map((label) {
            final isSelected = selectedTitle != null && selectedTitle == label;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _OptionChip(
                label: label,
                leadingIcon: Icons.radio_button_unchecked_rounded,
                isSelected: isSelected,
                isOutgoing: isOutgoing,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _InteractiveListOptions extends StatelessWidget {
  const _InteractiveListOptions({
    required this.listButtonTitle,
    required this.options,
    required this.selectedTitle,
    required this.isOutgoing,
  });

  final String? listButtonTitle;
  final List<String> options;
  final String? selectedTitle;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final headerText = (listButtonTitle != null && listButtonTitle!.isNotEmpty)
        ? listButtonTitle!
        : 'Pilih Opsi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.list_rounded,
              size: 16,
              color: isOutgoing ? AppColors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              headerText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOutgoing ? AppColors.white : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...options.map((label) {
          final isSelected = selectedTitle != null && selectedTitle == label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionChip(
              label: label,
              leadingIcon: Icons.chevron_right_rounded,
              isSelected: isSelected,
              isOutgoing: isOutgoing,
            ),
          );
        }),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.leadingIcon,
    required this.isSelected,
    required this.isOutgoing,
  });

  final String label;
  final IconData leadingIcon;
  final bool isSelected;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primary
        : isOutgoing
        ? AppColors.white.withValues(alpha: 0.35)
        : AppColors.borderLight;

    final textColor = isOutgoing ? AppColors.white : AppColors.neutral800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : (isOutgoing
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.surfaceSecondary),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isSelected ? Icons.check_circle_rounded : leadingIcon,
            size: 16,
            color: isSelected
                ? AppColors.primary
                : (isOutgoing
                      ? AppColors.white.withValues(alpha: 0.75)
                      : AppColors.neutral500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Status icon (unchanged from original)
// =============================================================================

class _PremiumStatusIcon extends StatelessWidget {
  const _PremiumStatusIcon({required this.message, this.onRetry});

  final ChatMessageModel message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isFailed) {
      return InkWell(
        onTap: onRetry,
        borderRadius: AppRadii.borderRadiusXl,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
        ),
      );
    }

    if (message.isSending) {
      return Icon(
        Icons.schedule_rounded,
        size: 14,
        color: AppColors.white.withValues(alpha: 0.50),
      );
    }

    if (message.isReadByCustomer) {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.readReceipt,
      );
    }

    if (message.isDelivered) {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.white.withValues(alpha: 0.70),
      );
    }

    return Icon(
      Icons.done_rounded,
      size: 14,
      color: AppColors.white.withValues(alpha: 0.60),
    );
  }
}
