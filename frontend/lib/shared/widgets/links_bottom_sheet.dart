import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/widgets/link_tile_item.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

/// Item representation for the LinksBottomSheet
class LinkItemData {
  final String url;
  final String title;

  const LinkItemData({
    required this.url,
    this.title = '',
  });

  /// Displays the custom title if provided, otherwise extracts a clean host
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return cleanDomain;
  }

  /// Extracts the host domain name (e.g., 'example.com')
  String get cleanDomain {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host.replaceFirst(RegExp(r'^www\.'), '');
      }
    } catch (_) {}
    return url.trim();
  }
}

/// **LinksBottomSheet - Premium bottom sheet to display multiple links**
///
/// Follows `design.md`: 28px top corner radius, dark theme, Inter typography,
/// touch targets >= 44x44, clean cards with Title + Domain Subtitle.
/// Tapping a card immediately navigates to the URL and dismisses the sheet.
class LinksBottomSheet extends StatelessWidget {
  final String title;
  final List<LinkItemData> links;
  final String source;
  final String medium;
  final String? campaign;
  final Future<void> Function(LinkItemData item)? onLinkTapped;

  const LinksBottomSheet({
    Key? key,
    this.title = 'Links',
    required this.links,
    this.source = 'vayug',
    this.medium = 'multi_link',
    this.campaign,
    this.onLinkTapped,
  }) : super(key: key);

  /// Helper to show the sheet easily from any screen
  static Future<void> show(
    BuildContext context, {
    String title = 'Links',
    required List<LinkItemData> links,
    String source = 'vayug',
    String medium = 'multi_link',
    String? campaign,
    Future<void> Function(LinkItemData item)? onLinkTapped,
  }) {
    if (links.isEmpty) return Future.value();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => LinksBottomSheet(
        title: title,
        links: links,
        source: source,
        medium: medium,
        campaign: campaign,
        onLinkTapped: onLinkTapped,
      ),
    );
  }

  Future<void> _handleNavigate(BuildContext context, LinkItemData item) async {
    Navigator.of(context).pop();

    if (onLinkTapped != null) {
      await onLinkTapped!(item);
      return;
    }

    final enrichedUrl = UrlUtils.enrichUrl(
      item.url.trim(),
      source: source,
      medium: medium,
      campaign: campaign,
    );

    AppLogger.log('🔗 LinksBottomSheet: Launching URL: $enrichedUrl');
    try {
      final uri = Uri.tryParse(enrichedUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        VayuSnackBar.showError(context, 'Could not open link in browser.');
      }
    } catch (e) {
      AppLogger.log('❌ LinksBottomSheet: Error launching link: $e');
      if (context.mounted) {
        VayuSnackBar.showError(context, 'Error opening link.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.space24,
          right: AppSpacing.space24,
          top: AppSpacing.space12,
          bottom: AppSpacing.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle Indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.vSpace16,

            // Sheet Title
            Text(
              title.trim().isNotEmpty ? title : 'Links',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.vSpace16,

            // List of Links
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: links.length,
                separatorBuilder: (_, __) => AppSpacing.vSpace8,
                itemBuilder: (context, index) {
                  final item = links[index];
                  return LinkTileItem(
                    item: item,
                    onTap: () => _handleNavigate(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
