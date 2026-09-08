import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

/// **MultiLinkEditorSheet - Allows adding/editing up to 5 links with custom titles**
///
/// Follows `design.md`: 28px bottom sheet radius, dark theme, Inter typography,
/// clean 8pt spacing grid, max 250 lines per file.
class MultiLinkEditorSheet extends StatefulWidget {
  final List<LinkItemData> initialLinks;
  final ValueChanged<List<LinkItemData>> onSave;
  final int maxLinks;

  const MultiLinkEditorSheet({
    Key? key,
    required this.initialLinks,
    required this.onSave,
    this.maxLinks = 5,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required List<LinkItemData> initialLinks,
    required ValueChanged<List<LinkItemData>> onSave,
    int maxLinks = 5,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MultiLinkEditorSheet(
        initialLinks: initialLinks,
        onSave: onSave,
        maxLinks: maxLinks,
      ),
    );
  }

  @override
  State<MultiLinkEditorSheet> createState() => _MultiLinkEditorSheetState();
}

class _LinkControllers {
  final TextEditingController titleController;
  final TextEditingController urlController;

  _LinkControllers({String title = '', String url = ''})
      : titleController = TextEditingController(text: title),
        urlController = TextEditingController(text: url);

  void dispose() {
    titleController.dispose();
    urlController.dispose();
  }
}

class _MultiLinkEditorSheetState extends State<MultiLinkEditorSheet> {
  final List<_LinkControllers> _controllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLinks.isNotEmpty) {
      for (final link in widget.initialLinks) {
        _controllers.add(
          _LinkControllers(title: link.title, url: link.url),
        );
      }
    } else {
      _controllers.add(_LinkControllers());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addLink() {
    if (_controllers.length >= widget.maxLinks) {
      VayuSnackBar.showInfo(context, 'Maximum ${widget.maxLinks} links allowed.');
      return;
    }
    setState(() {
      _controllers.add(_LinkControllers());
    });
  }

  void _removeLink(int index) {
    if (_controllers.length == 1) {
      _controllers[0].titleController.clear();
      _controllers[0].urlController.clear();
      setState(() {});
      return;
    }
    setState(() {
      final removed = _controllers.removeAt(index);
      removed.dispose();
    });
  }

  void _handleSave() {
    final List<LinkItemData> validLinks = [];

    for (final c in _controllers) {
      final rawUrl = c.urlController.text.trim();
      if (rawUrl.isEmpty) continue;

      String formattedUrl = rawUrl;
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.tryParse(formattedUrl);
      if (uri == null || !uri.hasAuthority) {
        VayuSnackBar.showError(context, 'Please enter a valid URL (e.g. example.com)');
        return;
      }

      validLinks.add(LinkItemData(
        url: formattedUrl,
        title: c.titleController.text.trim(),
      ));
    }

    widget.onSave(validLinks);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.spacing24,
        left: AppSpacing.spacing24,
        right: AppSpacing.spacing24,
        top: AppSpacing.spacing12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(
            'Promotional Links',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vSpace4,
          Text(
            'Add up to ${widget.maxLinks} links for viewers to visit.',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.vSpace16,
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _controllers.length,
              separatorBuilder: (_, __) => AppSpacing.vSpace12,
              itemBuilder: (context, index) {
                final c = _controllers[index];
                return Container(
                  padding: EdgeInsets.all(AppSpacing.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: c.titleController,
                              style: AppTypography.bodySmall,
                              decoration: const InputDecoration(
                                hintText: 'Title (e.g., Website, Store)',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: () => _removeLink(index),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.borderSecondary, height: 1),
                      TextField(
                        controller: c.urlController,
                        style: AppTypography.bodySmall,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'URL (https://...)',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_controllers.length < widget.maxLinks) ...[
            AppSpacing.vSpace12,
            TextButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Another Link'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
              ),
            ),
          ],
          AppSpacing.vSpace16,
          AppButton(
            onPressed: _handleSave,
            label: 'Save Links',
            variant: AppButtonVariant.primary,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
