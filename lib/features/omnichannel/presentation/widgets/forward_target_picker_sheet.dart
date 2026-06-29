import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';

/// Picker tujuan teruskan pesan (BRIEF 5A-FORWARD-APP). Modal bottom sheet
/// daftar percakapan tujuan (WhatsApp-only, exclude sumber — difilter di
/// controller). Tap baris -> tutup -> [onPick] dgn id tujuan. Empty-state bila
/// kosong. Di-gate `messageForwardEnabled` di call site (dashboard).
Future<void> showForwardTargetPickerSheet({
  required BuildContext context,
  required List<OmnichannelConversationListItemModel> items,
  required void Function(int targetConversationId) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ForwardTargetPickerSheet(items: items, onPick: onPick);
    },
  );
}

class _ForwardTargetPickerSheet extends StatelessWidget {
  const _ForwardTargetPickerSheet({required this.items, required this.onPick});

  final List<OmnichannelConversationListItemModel> items;
  final void Function(int targetConversationId) onPick;

  void _handlePick(
    BuildContext context,
    OmnichannelConversationListItemModel item,
  ) {
    Navigator.of(context).pop();
    onPick(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadii.borderRadiusXxl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: AppRadii.borderRadiusPill,
                  ),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const _ForwardTargetEmpty()
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(item.customerPhone ?? ''),
                          onTap: () => _handlePick(context, item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForwardTargetEmpty extends StatelessWidget {
  const _ForwardTargetEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'Tak ada percakapan tujuan.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral500,
          ),
        ),
      ),
    );
  }
}
