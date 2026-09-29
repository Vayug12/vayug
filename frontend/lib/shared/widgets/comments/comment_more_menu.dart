import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class CommentMoreMenu extends StatelessWidget {
  final String content;
  final VoidCallback? onDelete;

  const CommentMoreMenu({super.key, required this.content, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.minTouchTargetApple,
      child: PopupMenuButton<String>(
        tooltip: AppText.get('comment_options', fallback: 'Comment options'),
        icon: const Icon(Icons.more_horiz_rounded,
            size: 20, color: AppColors.textSecondary),
        padding: EdgeInsets.zero,
        color: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusCard),
        onSelected: (value) async {
          HapticFeedback.selectionClick();
          if (value == 'delete') {
            onDelete?.call();
          } else if (value == 'copy') {
            await Clipboard.setData(ClipboardData(text: content));
            if (context.mounted) {
              VayuSnackBar.showSuccess(context,
                  AppText.get('comment_copied', fallback: 'Comment copied'));
            }
          }
        },
        itemBuilder: (_) => [
          _item('copy', Icons.copy_rounded,
              AppText.get('btn_copy', fallback: 'Copy'), AppColors.textPrimary),
          if (onDelete != null)
            _item('delete', Icons.delete_outline_rounded,
                AppText.get('btn_delete'), AppColors.error),
        ],
      ),
    );
  }

  PopupMenuItem<String> _item(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: AppSpacing.minTouchTarget,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: AppSpacing.spacing3),
        Text(label, style: AppTypography.bodyMedium.copyWith(color: color)),
      ]),
    );
  }
}
