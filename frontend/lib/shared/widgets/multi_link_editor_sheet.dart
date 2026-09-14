import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/services/resource_upload_service.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

/// **MultiLinkEditorSheet - Clean, professional Apple HIG-compliant link & resource editor**
///
/// Allows creators and advertisers to manage up to 5 promotional links or direct file attachments (APK, PDF, Notes, Docs).
/// Adheres strictly to `apple.md` and `frontend/design.md`:
/// - 28px bottom sheet radius (`AppRadius.sheet`)
/// - 8pt spacing grid (`AppSpacing.space*`)
/// - Discrete card components with 10px squircle icons (`AppRadius.squircle`)
/// - 44x44 minimum touch targets
/// - Direct file attachments that map directly to the existing "Visit Now" flow
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusSheet,
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
  int showAtSeconds;
  bool isUploading = false;
  double uploadProgress = 0.0;
  String? attachedFileName;
  String? attachedFileSize;
  CancelToken? cancelToken;

  _LinkControllers({String title = '', String url = '', this.showAtSeconds = 0})
      : titleController = TextEditingController(text: title),
        urlController = TextEditingController(text: url) {
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      final lastPath = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '';
      final lower = lastPath.toLowerCase();
      if (lower.endsWith('.apk') ||
          lower.endsWith('.pdf') ||
          lower.endsWith('.zip') ||
          lower.endsWith('.docx') ||
          lower.endsWith('.txt')) {
        attachedFileName = lastPath;
      }
    }
  }

  void dispose() {
    cancelToken?.cancel('Sheet closed');
    titleController.dispose();
    urlController.dispose();
  }
}

class _MultiLinkEditorSheetState extends State<MultiLinkEditorSheet> {
  final List<_LinkControllers> _controllers = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLinks.isNotEmpty) {
      for (final link in widget.initialLinks) {
        _controllers.add(
          _LinkControllers(
            title: link.title,
            url: link.url,
            showAtSeconds: link.showAtSeconds,
          ),
        );
      }
    } else {
      _controllers.add(_LinkControllers());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    // Scroll to new item smoothly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _removeLink(int index) {
    if (_controllers.length == 1) {
      _controllers[0].cancelToken?.cancel('Removed');
      _controllers[0].titleController.clear();
      _controllers[0].urlController.clear();
      _controllers[0].attachedFileName = null;
      _controllers[0].attachedFileSize = null;
      _controllers[0].isUploading = false;
      setState(() {});
      return;
    }
    setState(() {
      final removed = _controllers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickAndUploadFile(_LinkControllers controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'apk',
          'zip',
          'doc',
          'docx',
          'txt',
          'epub',
          'xlsx',
          'pptx'
        ],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final fileSize = await file.length();

      if (fileSize > 200 * 1024 * 1024) {
        if (mounted) {
          VayuSnackBar.showError(context, 'File size exceeds 200MB limit');
        }
        return;
      }

      final cancelToken = CancelToken();
      setState(() {
        controller.isUploading = true;
        controller.uploadProgress = 0.0;
        controller.cancelToken = cancelToken;
      });

      final uploadResult = await ResourceUploadService().uploadResource(
        file: file,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              controller.uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          controller.isUploading = false;
          controller.urlController.text = uploadResult.url;
          controller.attachedFileName = uploadResult.fileName;
          controller.attachedFileSize = uploadResult.formattedSize;

          if (controller.titleController.text.trim().isEmpty) {
            final fileName = uploadResult.fileName;
            final ext = fileName.contains('.')
                ? fileName.split('.').last.toUpperCase()
                : '';
            final baseName = fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;
            controller.titleController.text = ext.isNotEmpty ? '$baseName ($ext)' : baseName;
          }
        });
        VayuSnackBar.showSuccess(context, 'File attached successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          controller.isUploading = false;
        });
        VayuSnackBar.showError(context, 'Upload error: $e');
      }
    }
  }

  void _removeAttachment(_LinkControllers controller) {
    setState(() {
      controller.attachedFileName = null;
      controller.attachedFileSize = null;
      controller.urlController.clear();
    });
  }

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.apk')) return Icons.android_rounded;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.zip')) return Icons.folder_zip_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  void _handleSave() {
    for (final c in _controllers) {
      if (c.isUploading) {
        VayuSnackBar.showInfo(context, 'Please wait for files to finish uploading.');
        return;
      }
    }

    final List<LinkItemData> validLinks = [];

    for (int i = 0; i < _controllers.length; i++) {
      final c = _controllers[i];
      final rawUrl = c.urlController.text.trim();
      final title = c.titleController.text.trim();

      if (rawUrl.isEmpty) {
        if (title.isNotEmpty) {
          VayuSnackBar.showError(context, 'Please enter a URL or attach a file for Link ${i + 1}');
          return;
        }
        continue;
      }

      String formattedUrl = rawUrl;
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final result = UrlUtils.validateUrl(formattedUrl);
      if (!result.isValid) {
        VayuSnackBar.showError(
          context,
          'Link ${i + 1}: ${result.userMessage}',
        );
        return;
      }

      validLinks.add(LinkItemData(
        url: formattedUrl,
        title: title,
        showAtSeconds: c.showAtSeconds,
      ));
    }

    widget.onSave(validLinks);
    Navigator.of(context).pop();
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    TextEditingController? controller,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.textTertiary,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: controller != null && controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 16),
              color: AppColors.textTertiary,
              splashRadius: 18,
              onPressed: () {
                controller.clear();
                setState(() {});
              },
            )
          : null,
      filled: true,
      fillColor: AppColors.backgroundSecondary,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.space16, vertical: AppSpacing.space12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.borderSecondary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(
          color: AppColors.borderSecondary.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space16,
          left: AppSpacing.space16,
          right: AppSpacing.space16,
          top: AppSpacing.space12,
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
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.vSpace16,

            // Sheet Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Promotional Links',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  splashRadius: 22,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTargetApple,
                    minHeight: AppSpacing.minTouchTargetApple,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            AppSpacing.vSpace16,

            // Scrollable Links List
            Flexible(
              child: ListView.separated(
                controller: _scrollController,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _controllers.length,
                separatorBuilder: (_, __) => AppSpacing.vSpace12,
                itemBuilder: (context, index) {
                  final c = _controllers[index];
                  final hasFile = c.attachedFileName != null;

                  return Container(
                    padding: AppSpacing.edgeInsetsAll16,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: AppColors.borderSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Icon + Link # + Attach File Action + Delete
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.squircle),
                              ),
                              child: Icon(
                                hasFile
                                    ? _getFileIcon(c.attachedFileName!)
                                    : Icons.link_rounded,
                                color: AppColors.primaryLight,
                                size: 16,
                              ),
                            ),
                            AppSpacing.hSpace8,
                            Text(
                              'Link ${index + 1}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),

                            // Attach File Pill Button
                            if (!c.isUploading)
                              InkWell(
                                onTap: () => _pickAndUploadFile(c),
                                borderRadius: BorderRadius.circular(AppRadius.button),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space12,
                                    vertical: AppSpacing.space4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.button),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.attach_file_rounded,
                                        size: 14,
                                        color: AppColors.primaryLight,
                                      ),
                                      AppSpacing.hSpace4,
                                      Text(
                                        hasFile ? 'Change File' : 'Attach File',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.primaryLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            AppSpacing.hSpace4,

                            // Delete Card Action
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              color: AppColors.error.withValues(alpha: 0.85),
                              splashRadius: 20,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              tooltip: 'Remove link',
                              onPressed: () => _removeLink(index),
                            ),
                          ],
                        ),
                        AppSpacing.vSpace12,

                        // Uploading Progress Indicator
                        if (c.isUploading) ...[
                          Container(
                            padding: AppSpacing.edgeInsetsAll12,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                    AppSpacing.hSpace8,
                                    Expanded(
                                      child: Text(
                                        'Uploading... ${(c.uploadProgress * 100).toInt()}%',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        c.cancelToken?.cancel('Cancelled');
                                        setState(() {
                                          c.isUploading = false;
                                        });
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.vSpace8,
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: c.uploadProgress,
                                    minHeight: 4,
                                    backgroundColor: AppColors.backgroundTertiary,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.vSpace8,
                        ],

                        // Attached File Badge (if file attached)
                        if (hasFile && !c.isUploading) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.space12,
                              vertical: AppSpacing.space8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(AppRadius.input),
                              border: Border.all(
                                color: AppColors.borderSecondary,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getFileIcon(c.attachedFileName!),
                                  size: 16,
                                  color: AppColors.primaryLight,
                                ),
                                AppSpacing.hSpace8,
                                Expanded(
                                  child: Text(
                                    '${c.attachedFileName!} • ${c.attachedFileSize ?? ''}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeAttachment(c),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.vSpace8,
                        ],

                        // Title Input
                        TextField(
                          controller: c.titleController,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: _buildInputDecoration(
                            hintText: 'Title (e.g. Website, Notes, App)',
                            controller: c.titleController,
                          ),
                        ),
                        AppSpacing.vSpace8,

                        // URL Input
                        TextField(
                          controller: c.urlController,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (_) => setState(() {}),
                          decoration: _buildInputDecoration(
                            hintText: 'https://example.com or attach file above',
                            prefixIcon: Icon(
                              hasFile
                                    ? _getFileIcon(c.attachedFileName!)
                                    : Icons.language_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                            controller: c.urlController,
                          ),
                        ),
                        AppSpacing.vSpace8,

                        // Appearance Timing Selector
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.space12,
                            vertical: AppSpacing.space8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            border: Border.all(
                              color: AppColors.borderSecondary,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.primaryLight),
                                  AppSpacing.hSpace8,
                                  Text(
                                    'Show at',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    c.showAtSeconds == 0
                                        ? 'Start (0s)'
                                        : '${c.showAtSeconds}s',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: c.showAtSeconds > 0 ? AppColors.primaryLight : AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: AppColors.primaryLight,
                                  inactiveTrackColor: AppColors.borderSecondary,
                                  thumbColor: AppColors.primaryLight,
                                ),
                                child: Slider(
                                  value: c.showAtSeconds.toDouble().clamp(0.0, 120.0),
                                  min: 0,
                                  max: 120,
                                  divisions: 120,
                                  onChanged: (val) {
                                    setState(() {
                                      c.showAtSeconds = val.round();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Add Link Button
            if (_controllers.length < widget.maxLinks) ...[
              AppSpacing.vSpace12,
              InkWell(
                onTap: _addLink,
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.primaryLight,
                      ),
                      AppSpacing.hSpace8,
                      Text(
                        'Add Link',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            AppSpacing.vSpace16,

            // Save Links Action Button
            AppButton(
              onPressed: _handleSave,
              label: 'Save Links',
              variant: AppButtonVariant.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
