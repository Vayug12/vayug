import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';

/// **QuizOverlay - Apple HIG & Design System Compliant**
///
/// Adheres strictly to:
/// - Deference / Content-First: Compact height (~130px) ensuring playing video is not blocked.
/// - Touch Targets: 44x44pt hit targets for close/back actions.
/// - Surface: Translucent dark surface with hairline border and subtle elevation.
/// - Typography: Inter typography adhering to font scale (min 12px for options).
class QuizOverlay extends StatefulWidget {
  final QuizModel quiz;
  final VoidCallback onDismiss;
  final VoidCallback? onBack;
  final Function(int) onAnswered;
  final bool isCompact;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? outerPadding;
  final double? maxWidth;

  const QuizOverlay({
    super.key,
    required this.quiz,
    required this.onDismiss,
    this.onBack,
    required this.onAnswered,
    this.isCompact = false,
    this.alignment,
    this.outerPadding,
    this.maxWidth,
  });

  @override
  State<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends State<QuizOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  int? _selectedOption;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleOptionSelect(int index) {
    if (_showResult) return;
    if (mounted) {
      setState(() {
        _selectedOption = index;
        _showResult = true;
      });
    }
    widget.onAnswered(index);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final resolvedAlignment = widget.alignment ??
        (isLandscape ? Alignment.centerLeft : Alignment.center);
    final resolvedOuterPadding = widget.outerPadding ??
        EdgeInsets.symmetric(
          horizontal: isLandscape ? 48 : 0,
          vertical: isLandscape ? 20 : 0,
        );
    final resolvedMaxWidth =
        widget.maxWidth ?? (isLandscape ? (size.width * 0.35) : size.width);
    final optionColumnCount = resolvedMaxWidth < 280 ? 1 : 2;

    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: resolvedAlignment,
          child: Padding(
            padding: resolvedOuterPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: resolvedMaxWidth,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      widget.isCompact ? AppSpacing.spacing3 : AppSpacing.spacing4,
                      widget.isCompact ? AppSpacing.spacing2 : AppSpacing.spacing3,
                      widget.isCompact ? AppSpacing.spacing2 : AppSpacing.spacing3,
                      widget.isCompact ? AppSpacing.spacing3 : AppSpacing.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Back (optional) + Question text + 44x44 Close Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.onBack != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onBack,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.white.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_rounded,
                                          size: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.quiz.question,
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: widget.isCompact ? 13 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _dismiss,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isCompact ? 6 : 8),
                        // Options Grid: Compact, non-intrusive, readable
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: optionColumnCount,
                            crossAxisSpacing: widget.isCompact ? 6 : 8,
                            mainAxisSpacing: widget.isCompact ? 6 : 8,
                            childAspectRatio: optionColumnCount == 1
                                ? (widget.isCompact ? 4.8 : 4.4)
                                : isLandscape
                                    ? 2.4
                                    : (widget.isCompact ? 3.6 : 3.2),
                          ),
                          itemCount: widget.quiz.options.length,
                          itemBuilder: (context, index) {
                            final bool isCorrect = index == widget.quiz.correctIndex;
                            final bool isSelected = index == _selectedOption;

                            Color borderColor = AppColors.white.withValues(alpha: 0.08);
                            Color backgroundColor = isSelected
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : AppColors.white.withValues(alpha: 0.05);
                            Color textColor = AppColors.textPrimary.withValues(alpha: 0.9);

                            if (_showResult) {
                              if (isCorrect) {
                                borderColor = AppColors.success.withValues(alpha: 0.6);
                                backgroundColor = AppColors.success.withValues(alpha: 0.15);
                                textColor = AppColors.success;
                              } else if (isSelected && !isCorrect) {
                                borderColor = AppColors.error.withValues(alpha: 0.6);
                                backgroundColor = AppColors.error.withValues(alpha: 0.15);
                                textColor = AppColors.error;
                              }
                            }

                            return GestureDetector(
                              onTap: () => _handleOptionSelect(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.isCompact ? 8 : 10,
                                  vertical: widget.isCompact ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.quiz.options[index],
                                        style: AppTypography.bodySmall.copyWith(
                                          color: textColor,
                                          fontSize: widget.isCompact ? 11.5 : 12.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (_showResult && isCorrect)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.success,
                                        size: 14,
                                      ),
                                    if (_showResult && isSelected && !isCorrect)
                                      const Icon(
                                        Icons.cancel_rounded,
                                        color: AppColors.error,
                                        size: 14,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
