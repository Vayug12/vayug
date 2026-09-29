import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/comments/comment_avatar.dart';
import 'package:vayug/shared/widgets/comments/comment_emoji_bar.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class CommentInputField extends StatefulWidget {
  final String? userProfilePic;
  final bool isSubmitting;
  final bool isSignedIn;
  final Future<bool> Function(String) onSubmit;
  final VoidCallback onSignInRequired;

  const CommentInputField({
    super.key,
    this.userProfilePic,
    this.isSubmitting = false,
    this.isSignedIn = true,
    required this.onSubmit,
    required this.onSignInRequired,
  });

  @override
  State<CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<CommentInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

  bool get _isBusy => _sending || widget.isSubmitting;
  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_isBusy;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  void _insertEmoji(String emoji) {
    if (_isBusy) return;
    if (!widget.isSignedIn) {
      widget.onSignInRequired();
      return;
    }
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    if (next.characters.length > 500) return;
    HapticFeedback.selectionClick();
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _handleSubmit() async {
    if (!widget.isSignedIn) {
      widget.onSignInRequired();
      return;
    }
    if (!_canSubmit) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    var success = false;
    try {
      success = await widget.onSubmit(_controller.text.trim());
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (success) {
      _controller.clear();
      _focusNode.unfocus();
    } else {
      VayuSnackBar.showError(
          context,
          AppText.get('comment_send_error',
              fallback: 'Could not post your comment. Please try again.'));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _focusNode.hasFocus
                  ? CommentEmojiBar(onSelected: _insertEmoji, enabled: !_isBusy)
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacing5,
                  vertical: AppSpacing.spacing3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    height: AppSpacing.minTouchTargetApple,
                    child: Center(
                        child: CommentAvatar(imageUrl: widget.userProfilePic)),
                  ),
                  SizedBox(width: AppSpacing.spacing3),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePrimary,
                        borderRadius: AppRadius.borderRadiusCardLarge,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: !widget.isSignedIn || _isBusy,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        style: AppTypography.bodyMedium,
                        cursorColor: AppColors.primaryLight,
                        decoration: InputDecoration(
                          hintText: widget.isSignedIn
                              ? AppText.get('comment_hint',
                                  fallback: 'Add a comment…')
                              : AppText.get('comment_sign_in',
                                  fallback: 'Sign in to comment'),
                          hintStyle: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.spacing4,
                              vertical: AppSpacing.spacing3),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                        onTap: () {
                          if (!widget.isSignedIn) {
                            _focusNode.unfocus();
                            widget.onSignInRequired();
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.spacing2),
                  IconButton(
                    tooltip:
                        AppText.get('comment_send', fallback: 'Post comment'),
                    onPressed: _canSubmit ? _handleSubmit : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.surfacePrimary,
                      foregroundColor: AppColors.white,
                      disabledForegroundColor: AppColors.textTertiary,
                    ),
                    icon: _isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primaryLight))
                        : const Icon(Icons.arrow_upward_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
