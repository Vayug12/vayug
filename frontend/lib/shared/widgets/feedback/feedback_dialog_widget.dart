import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'dart:convert';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:vayug/shared/services/install_attribution_service.dart';

class FeedbackDialogWidget extends StatefulWidget {
  const FeedbackDialogWidget({super.key});

  @override
  State<FeedbackDialogWidget> createState() => _FeedbackDialogWidgetState();
}

class _FeedbackDialogWidgetState extends State<FeedbackDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  double _rating = 0;
  final TextEditingController _messageController = TextEditingController();
  bool _submitting = false;

  final Map<int, Map<String, dynamic>> _ratingData = {
    1: {'emoji': '😢', 'text': 'Oh no!', 'color': Colors.red},
    2: {'emoji': '😞', 'text': 'Could be better', 'color': Colors.orange},
    3: {'emoji': '😐', 'text': 'We can improve', 'color': Colors.amber},
    4: {'emoji': '🙂', 'text': 'Good!', 'color': Colors.lightGreen},
    5: {'emoji': '🤩', 'text': 'Awesome!', 'color': Colors.green},
  };

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchPlayStore() async {
    const packageName = "com.snehayog.app";
    final url = Uri.parse("market://details?id=$packageName");
    final webUrl = Uri.parse(
        "https://play.google.com/store/apps/details?id=$packageName");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      VayuSnackBar.showWarning(context, 'Please select a star rating');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      // Get user data for feedback submission
      final authService = AuthService();
      final userData = await authService.getUserData();
      final attribution =
          await InstallAttributionService.instance.getAttributionPayload();
      final payload = <String, dynamic>{
        'rating': _rating.toInt(),
        'comments': _messageController.text.trim(),
        'userEmail': userData?['email'] ?? 'anonymous@user.com',
        'userId': userData?['googleId'] ?? userData?['id'] ?? 'anonymous',
      };

      if (attribution.isNotEmpty) {
        payload['attribution'] = attribution;
      }

      // Submit feedback to backend
      final response = await httpClientService.post(
        Uri.parse('${NetworkHelper.apiBaseUrl}/feedback/submit'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;

        // Handle high ratings (4 or 5 stars) — directly open Play Store
        if (_rating >= 4) {
          Navigator.of(context).pop(true); // Close dialog first
          VayuSnackBar.showSuccess(
            context,
            'Thanks! Taking you to the Play Store to rate us',
            duration: const Duration(seconds: 2),
          );
          _launchPlayStore(); // Directly navigate to Play Store
        } else {
          Navigator.of(context).pop(true);
          VayuSnackBar.showSuccess(context,
              'Thanks for your feedback! We will use it to improve our app.');
        }
      } else {
        throw Exception('Failed to submit feedback');
      }
    } catch (e) {
      if (mounted) {
        VayuSnackBar.showError(context, 'Error submitting feedback: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int ratingInt = _rating.toInt();
    final currentData = _ratingData[ratingInt];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.borderPrimary.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Dynamic & Compact)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: currentData != null
                      ? Text(
                          '${currentData['emoji']}  ${currentData['text']}',
                          key: ValueKey<int>(ratingInt),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : Text(
                          'Rate your experience',
                          key: const ValueKey<String>('default_title'),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rating == 0
                      ? 'Tap a star to rate'
                      : 'Please leave feedback (optional)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Star rating row
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final filled = index < _rating.round();
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _rating = index + 1.0);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: filled
                                ? const Color(0xFFFFB800)
                                : AppColors.borderPrimary,
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),

                // Compact comment input
                TextFormField(
                  controller: _messageController,
                  minLines: 2,
                  maxLines: 3,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.backgroundPrimary,
                    hintText: 'Share your thoughts (optional)',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide(
                        color: AppColors.borderPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide(
                        color: AppColors.borderPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Primary & Secondary Buttons
                AppButton(
                  onPressed: _submitting ? null : _submit,
                  label: 'Submit',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  isLoading: _submitting,
                  isFullWidth: true,
                ),
                const SizedBox(height: 4),
                AppButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  label: 'Maybe Later',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.small,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
