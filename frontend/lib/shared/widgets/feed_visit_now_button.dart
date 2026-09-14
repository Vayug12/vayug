import 'package:flutter/material.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class FeedVisitNowButton extends StatefulWidget {
  final String url;
  final String source;
  final String medium;
  final String campaign;
  final AppButtonVariant variant;
  final AppButtonSize size;

  const FeedVisitNowButton({
    Key? key,
    required this.url,
    this.source = 'vayug',
    this.medium = 'video_feed',
    this.campaign = 'creator_visit',
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.small,
  }) : super(key: key);

  @override
  State<FeedVisitNowButton> createState() => _FeedVisitNowButtonState();
}

class _FeedVisitNowButtonState extends State<FeedVisitNowButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    final trimmedUrl = widget.url.trim();
    if (trimmedUrl.isEmpty) {
      if (mounted) {
        VayuSnackBar.showError(context, 'No link available for this video.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final enrichedUrl = UrlUtils.enrichUrl(
        trimmedUrl,
        source: widget.source,
        medium: widget.medium,
        campaign: widget.campaign,
      );

      final uri = Uri.tryParse(enrichedUrl);
      if (uri == null) {
        if (mounted) {
          VayuSnackBar.showError(context, 'This link format is invalid and cannot be opened.');
        }
        return;
      }

      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          final scheme = uri.scheme.toLowerCase();
          if (scheme != 'http' && scheme != 'https') {
            VayuSnackBar.showError(context, 'This link type is not supported.');
          } else {
            VayuSnackBar.showError(
              context,
              'No browser found to open this link. Please check if a browser app is installed.',
            );
          }
        }
        return;
      }

      final success = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!success && mounted) {
        VayuSnackBar.showError(
          context,
          'Could not open link. The website may be down or temporarily unavailable.',
        );
      }
    } catch (e) {
      AppLogger.log('❌ FeedVisitNowButton: Error opening link: $e');
      if (mounted) {
        VayuSnackBar.showError(
          context,
          'An unexpected error occurred while opening the link.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Visit Now',
      onPressed: _isLoading ? null : _handlePress,
      isLoading: _isLoading,
      icon: _isLoading
          ? null
          : const Icon(Icons.open_in_new, size: 14, color: Colors.white),
      variant: widget.variant,
      size: widget.size,
    );
  }
}
