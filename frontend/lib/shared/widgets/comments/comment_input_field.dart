import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/interactive_scale_button.dart';

class CommentInputField extends StatefulWidget {
  final String? userProfilePic;
  final bool isSubmitting;
  final bool isSignedIn;
  final ValueChanged<String> onSubmit;
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
  final TextEditingController _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final canSubmit = _controller.text.trim().isNotEmpty && !widget.isSubmitting;
    if (canSubmit != _canSubmit) {
      setState(() => _canSubmit = canSubmit);
    }
  }

  void _handleSubmit() {
    if (!widget.isSignedIn) {
      widget.onSignInRequired();
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSubmitting) return;

    widget.onSubmit(text);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spacing4,
        AppSpacing.spacing2,
        AppSpacing.spacing4,
        AppSpacing.spacing2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar
            _buildAvatar(),
            SizedBox(width: AppSpacing.spacing3),

            // Input Field (pill shape, no borders)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isSubmitting,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  maxLength: 500,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isSignedIn ? 'Add a comment...' : 'Sign in to comment...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.spacing4,
                      vertical: AppSpacing.spacing2,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onTap: () {
                    if (!widget.isSignedIn) {
                      FocusScope.of(context).unfocus();
                      widget.onSignInRequired();
                    }
                  },
                ),
              ),
            ),
            SizedBox(width: AppSpacing.spacing2),

            // Send Button
            widget.isSubmitting
                ? SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.spacing2),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : InteractiveScaleButton(
                    onTap: _canSubmit ? _handleSubmit : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _canSubmit ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: _canSubmit ? AppColors.white : AppColors.textTertiary,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    const size = 32.0;
    if (widget.userProfilePic != null && widget.userProfilePic!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.userProfilePic!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildFallbackAvatar(size),
        ),
      );
    }
    return _buildFallbackAvatar(size);
  }

  Widget _buildFallbackAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfacePrimary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }
}
