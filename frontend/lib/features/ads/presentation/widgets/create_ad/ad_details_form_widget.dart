import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/features/ads/presentation/widgets/create_ad/ad_multi_link_field.dart';

/// **AdDetailsFormWidget - Handles ad title, description, and link input**
/// For banner ads, only shows link field (title/description not needed)
class AdDetailsFormWidget extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController linkController;
  final Function() onClearErrors;
  final Function(String)? onFieldChanged;
  final String adType; // To determine which fields to show

  // **NEW: Validation states**
  final bool? isTitleValid;
  final bool? isDescriptionValid;
  final bool? isLinkValid;
  final String? titleError;
  final String? descriptionError;
  final String? linkError;

  // **Multi-Link Support**
  final List<LinkItemData>? additionalLinks;
  final ValueChanged<List<LinkItemData>>? onAdditionalLinksChanged;

  const AdDetailsFormWidget({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.linkController,
    required this.onClearErrors,
    required this.adType,
    this.onFieldChanged,
    // **NEW: Optional validation parameters**
    this.isTitleValid,
    this.isDescriptionValid,
    this.isLinkValid,
    this.titleError,
    this.descriptionError,
    this.linkError,
    this.additionalLinks,
    this.onAdditionalLinksChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isBanner = adType == 'banner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show title for all ad types (including banner)
        TextFormField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: isBanner ? 'Banner Title *' : 'Ad Title *',
            hintText: isBanner
                ? 'Enter headline (max 30 words)'
                : 'Enter ad title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isTitleValid == false)
                    ? AppColors.error
                    : AppColors.borderPrimary,
                width: (isTitleValid == false) ? 2.0 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isTitleValid == false)
                    ? AppColors.error
                    : AppColors.borderPrimary,
                width: (isTitleValid == false) ? 2.0 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isTitleValid == false)
                    ? AppColors.error
                    : AppColors.primary,
                width: (isTitleValid == false) ? 2.0 : 2.0,
              ),
            ),
            errorText: (isTitleValid == false) ? titleError : null,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          onChanged: (_) {
            onClearErrors();
            onFieldChanged?.call('title');
          },
        ),
        const SizedBox(height: 16),

        // Only show description for non-banner ads
        if (!isBanner) ...[
          TextFormField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Enter ad description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: (isDescriptionValid == false)
                      ? AppColors.error
                      : AppColors.borderPrimary,
                  width: (isDescriptionValid == false) ? 2.0 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: (isDescriptionValid == false)
                      ? AppColors.error
                      : AppColors.borderPrimary,
                  width: (isDescriptionValid == false) ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: (isDescriptionValid == false)
                      ? AppColors.error
                      : AppColors.primary,
                  width: (isDescriptionValid == false) ? 2.0 : 2.0,
                ),
              ),
              errorText:
                  (isDescriptionValid == false) ? descriptionError : null,
              errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
            maxLines: 3,
            onChanged: (_) {
              onClearErrors();
              onFieldChanged?.call('description');
            },
          ),
          const SizedBox(height: 16),
        ],

        // Link field - always visible for all ad types
        TextFormField(
          controller: linkController,
          decoration: InputDecoration(
            labelText: isBanner ? 'Destination URL *' : 'Landing Page URL *',
            hintText: 'https://example.com',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isLinkValid == false)
                    ? AppColors.error
                    : AppColors.borderPrimary,
                width: (isLinkValid == false) ? 2.0 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isLinkValid == false)
                    ? AppColors.error
                    : AppColors.borderPrimary,
                width: (isLinkValid == false) ? 2.0 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isLinkValid == false)
                    ? AppColors.error
                    : AppColors.primary,
                width: (isLinkValid == false) ? 2.0 : 2.0,
              ),
            ),
            helperText: isBanner
                ? 'Opens when users tap your ad'
                : 'Website opened when users tap your ad',
            errorText: (isLinkValid == false) ? linkError : null,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) {
            onClearErrors();
            onFieldChanged?.call('link');
          },
        ),
        if (onAdditionalLinksChanged != null) ...[
          const SizedBox(height: 16),
          AdMultiLinkField(
            links: additionalLinks ?? const [],
            onLinksChanged: onAdditionalLinksChanged!,
          ),
        ],
      ],
    );
  }
}
