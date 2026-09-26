import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class FeedVisitNowButton extends StatefulWidget {
  final String url;
  final VideoModel? video;
  final VoidCallback? onCustomTap;
  final String source;
  final String medium;
  final String campaign;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isFullWidth;

  const FeedVisitNowButton({
    Key? key,
    this.url = '',
    this.video,
    this.onCustomTap,
    this.source = 'vayug',
    this.medium = 'video_feed',
    this.campaign = 'creator_visit',
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.small,
    this.isFullWidth = true,
  }) : super(key: key);

  @override
  State<FeedVisitNowButton> createState() => _FeedVisitNowButtonState();
}

class _FeedVisitNowButtonState extends State<FeedVisitNowButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    final video = widget.video;
    if (video != null && video.id.isNotEmpty) {
      unawaited(
        httpClientService
            .post(
              Uri.parse('${AppConfig.baseUrl}/api/videos/${video.id}/link-click'),
            )
            .then(
              (_) {},
              onError: (e) {
                AppLogger.log('⚠️ Failed to record link click: $e');
              },
            ),
      );
    }

    if (widget.onCustomTap != null) {
      widget.onCustomTap!();
      return;
    }

    if (video != null && video.validLinks.length > 1) {
      LinksBottomSheet.show(
        context,
        title: video.videoName,
        links: video.validLinks.map((l) => l.toLinkItemData()).toList(),
        source: widget.source,
        medium: widget.medium,
        campaign: widget.campaign,
      );
      return;
    }

    final targetUrl = video != null
        ? (video.validLinks.isNotEmpty
            ? video.validLinks.first.url
            : (video.link?.trim() ?? ''))
        : widget.url.trim();

    if (targetUrl.isEmpty) {
      if (mounted) {
        VayuSnackBar.showError(context, 'No link available for this video.');
      }
      return;
    }

    setState(() => _isLoading = true);

    if (mounted) {
      VayuSnackBar.showInfo(
        context,
        'Opening link...',
        duration: const Duration(seconds: 2),
      );
    }

    try {
      final enrichedUrl = UrlUtils.enrichUrl(
        targetUrl,
        source: widget.source,
        medium: widget.medium,
        campaign: widget.campaign,
      );

      final uri = Uri.tryParse(enrichedUrl);
      if (uri == null) {
        if (mounted) {
          VayuSnackBar.showError(
            context,
            'This link format is invalid and cannot be opened.',
          );
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

      final success =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        VayuSnackBar.showError(
          context,
          'Could not open link. Please check if a browser is available.',
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _handlePress,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize:
                    widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else ...[
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _isLoading ? 'Opening...' : 'Visit Now',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
