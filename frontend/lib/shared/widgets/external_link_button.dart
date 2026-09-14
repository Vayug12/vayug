import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class ExternalLinkButton extends StatefulWidget {
  final String url;
  final ThemeData theme;
  const ExternalLinkButton({Key? key, required this.url, required this.theme})
      : super(key: key);

  @override
  State<ExternalLinkButton> createState() => _ExternalLinkButtonState();
}

class _ExternalLinkButtonState extends State<ExternalLinkButton> {
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
        source: 'vayug',
        medium: 'visit_now',
      );

      AppLogger.log('🔗 ExternalLinkButton: Attempting to launch: $enrichedUrl');

      final uri = Uri.tryParse(enrichedUrl);
      if (uri == null) {
        AppLogger.log('❌ ExternalLinkButton: Uri.tryParse returned null for $enrichedUrl');
        if (mounted) {
          VayuSnackBar.showError(context, 'This link format is invalid and cannot be opened.');
        }
        return;
      }

      if (!await canLaunchUrl(uri)) {
        AppLogger.log('⚠️ ExternalLinkButton: canLaunchUrl returned false for $enrichedUrl');
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

      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        AppLogger.log('❌ ExternalLinkButton: launchUrl returned false for $enrichedUrl');
        if (mounted) {
          VayuSnackBar.showError(
            context,
            'Could not open link. The website may be down or temporarily unavailable.',
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ ExternalLinkButton: Exception while launching link: $e');
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
      onPressed: _isLoading ? null : _handlePress,
      isLoading: _isLoading,
      label: 'Visit Now',
      icon: _isLoading ? null : const Icon(Icons.open_in_new, color: Colors.white, size: 20),
      variant: AppButtonVariant.primary,
      size: AppButtonSize.medium,
      isFullWidth: true,
    );
  }
}
