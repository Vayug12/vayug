import 'package:flutter/material.dart';
import 'package:vayug/core/design/spacing.dart';

class CommentEmojiBar extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final bool enabled;
  const CommentEmojiBar({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  static const emojis = ['❤️', '😂', '🎉', '😢', '😮', '🔥', '👏', '🙌', '💯'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.spacing5),
        itemCount: emojis.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.spacing1),
        itemBuilder: (_, index) => TextButton(
          onPressed: enabled ? () => onSelected(emojis[index]) : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          child: Text(emojis[index], style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
