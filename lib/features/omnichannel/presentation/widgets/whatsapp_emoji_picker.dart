import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';

Future<void> showWhatsAppEmojiPicker({
  required BuildContext context,
  required ValueChanged<String> onEmojiSelected,
  VoidCallback? onBackspacePressed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 420),
    builder: (context) {
      return _WhatsAppEmojiPickerSheet(
        onEmojiSelected: onEmojiSelected,
        onBackspacePressed: onBackspacePressed,
      );
    },
  );
}

class _WhatsAppEmojiPickerSheet extends StatefulWidget {
  const _WhatsAppEmojiPickerSheet({
    required this.onEmojiSelected,
    this.onBackspacePressed,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onBackspacePressed;

  @override
  State<_WhatsAppEmojiPickerSheet> createState() =>
      _WhatsAppEmojiPickerSheetState();
}

class _WhatsAppEmojiPickerSheetState extends State<_WhatsAppEmojiPickerSheet> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.5;
    final pickerHeight = maxHeight.clamp(320.0, 420.0).toDouble();
    final selectedCategory = _emojiCategories[_selectedCategoryIndex];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: pickerHeight,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7D7D7),
                      borderRadius: AppRadii.borderRadiusPill,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: widget.onBackspacePressed,
                    icon: const Icon(
                      Icons.backspace_outlined,
                      color: AppColors.neutral500,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.neutral500),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  const Text(
                    'Emoji',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedCategory.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final category = _emojiCategories[index];
                  final isSelected = index == _selectedCategoryIndex;

                  return Material(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: AppRadii.borderRadiusLg,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCategoryIndex = index);
                      },
                      borderRadius: AppRadii.borderRadiusLg,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          category.icon,
                          size: 20,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.neutral500,
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemCount: _emojiCategories.length,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 380 ? 8 : 7;

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: selectedCategory.emojis.length,
                    itemBuilder: (context, index) {
                      final emoji = selectedCategory.emojis[index];

                      return Tooltip(
                        message: emoji,
                        child: Material(
                          color: Colors.white,
                          borderRadius: AppRadii.borderRadiusMd,
                          child: InkWell(
                            onTap: () => widget.onEmojiSelected(emoji),
                            borderRadius: AppRadii.borderRadiusMd,
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCategory {
  const _EmojiCategory({
    required this.label,
    required this.icon,
    required this.emojis,
  });

  final String label;
  final IconData icon;
  final List<String> emojis;
}

const List<_EmojiCategory> _emojiCategories = <_EmojiCategory>[
  _EmojiCategory(
    label: 'Smileys',
    icon: Icons.emoji_emotions_outlined,
    emojis: <String>[
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😋',
      '😛',
      '😜',
      '🤪',
      '🤗',
      '🤭',
      '🫢',
      '🤫',
      '🤔',
      '🫡',
      '😎',
      '🥳',
      '😤',
      '😭',
      '😡',
      '🥹',
      '😴',
    ],
  ),
  _EmojiCategory(
    label: 'People',
    icon: Icons.waving_hand_outlined,
    emojis: <String>[
      '👋',
      '🤚',
      '🖐️',
      '✋',
      '🫶',
      '🫰',
      '👌',
      '🤌',
      '🤏',
      '✌️',
      '🤞',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🙏',
      '💪',
      '🫱',
      '🫲',
      '🤝',
      '🫂',
      '👀',
      '🧠',
      '👨‍💻',
      '👩‍💻',
      '🧑‍💼',
      '👨‍🔧',
      '👩‍🔧',
      '🧑‍🚀',
      '👨‍⚕️',
      '👩‍⚕️',
      '🧑‍🏫',
      '🙋',
      '💁',
      '🙆',
      '🤷',
    ],
  ),
  _EmojiCategory(
    label: 'Animals',
    icon: Icons.pets_outlined,
    emojis: <String>[
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🐔',
      '🐧',
      '🐦',
      '🐤',
      '🦆',
      '🦅',
      '🦉',
      '🐴',
      '🦄',
      '🐝',
      '🦋',
      '🐢',
      '🐬',
      '🐳',
      '🦭',
      '🐘',
      '🦒',
      '🌸',
      '🌻',
      '🍀',
      '🌿',
    ],
  ),
  _EmojiCategory(
    label: 'Food',
    icon: Icons.restaurant_outlined,
    emojis: <String>[
      '🍎',
      '🍊',
      '🍉',
      '🍓',
      '🍇',
      '🥥',
      '🥑',
      '🌶️',
      '🥕',
      '🍔',
      '🍟',
      '🍕',
      '🌭',
      '🥪',
      '🌮',
      '🍜',
      '🍲',
      '🍛',
      '🍣',
      '🍤',
      '🍩',
      '🍪',
      '🎂',
      '🍫',
      '🍿',
      '☕',
      '🧋',
      '🥤',
      '🍵',
      '🍼',
    ],
  ),
  _EmojiCategory(
    label: 'Travel',
    icon: Icons.directions_car_outlined,
    emojis: <String>[
      '🚗',
      '🚕',
      '🚙',
      '🚌',
      '🚎',
      '🏎️',
      '🚓',
      '🚑',
      '🚒',
      '🚚',
      '🚛',
      '🚜',
      '🛵',
      '🏍️',
      '🚲',
      '✈️',
      '🛫',
      '🛬',
      '🚆',
      '🚂',
      '🚇',
      '🚤',
      '⛴️',
      '🚢',
      '🗺️',
      '📍',
      '🧳',
      '🏖️',
      '🏝️',
      '🏨',
    ],
  ),
  _EmojiCategory(
    label: 'Objects',
    icon: Icons.lightbulb_outline,
    emojis: <String>[
      '📱',
      '☎️',
      '💻',
      '⌚',
      '📷',
      '🎥',
      '🎧',
      '🎤',
      '🔋',
      '🔌',
      '💡',
      '🕯️',
      '🧯',
      '🛒',
      '💸',
      '💰',
      '💳',
      '🧾',
      '📦',
      '🎁',
      '📌',
      '📎',
      '✏️',
      '📝',
      '📚',
      '📅',
      '📍',
      '🔒',
      '🔑',
      '🪪',
      '🧸',
      '🎈',
      '🪄',
      '🪙',
    ],
  ),
  _EmojiCategory(
    label: 'Symbols',
    icon: Icons.favorite_border,
    emojis: <String>[
      '❤️',
      '🧡',
      '💛',
      '💚',
      '🩵',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❤️‍🔥',
      '❣️',
      '💕',
      '💞',
      '💯',
      '✅',
      '☑️',
      '✔️',
      '✖️',
      '❌',
      '⚠️',
      '🚫',
      '⛔',
      '⭐',
      '🌟',
      '✨',
      '🔥',
      '💥',
      '🎉',
      '🎊',
      '💬',
      '🗨️',
      '♻️',
      '🔔',
      '📣',
    ],
  ),
];
