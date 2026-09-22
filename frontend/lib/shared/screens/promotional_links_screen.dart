import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/services/resource_upload_service.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

/// **PromotionalLinksScreen (Hub Screen)**
///
/// Clean, non-cluttered screen managing promotional links for the "Visit Now" button.
/// Adheres to the Hub-and-Spoke model:
/// - Hub: Clean list of currently added links, add button, and save action.
/// - Spoke (`PromotionalLinkEditorScreen`): Focused single-link creation/editing.
class PromotionalLinksScreen extends StatefulWidget {
  final List<LinkItemData> initialLinks;
  final ValueChanged<List<LinkItemData>> onSave;
  final int maxLinks;
  final double videoDuration;

  const PromotionalLinksScreen({
    super.key,
    required this.initialLinks,
    required this.onSave,
    this.maxLinks = 5,
    this.videoDuration = 0.0,
  });

  /// Navigates to the PromotionalLinksScreen
  static Future<List<LinkItemData>?> push(
    BuildContext context, {
    required List<LinkItemData> initialLinks,
    required ValueChanged<List<LinkItemData>> onSave,
    int maxLinks = 5,
    double videoDuration = 0.0,
  }) {
    return Navigator.push<List<LinkItemData>>(
      context,
      MaterialPageRoute(
        builder: (_) => PromotionalLinksScreen(
          initialLinks: initialLinks,
          onSave: onSave,
          maxLinks: maxLinks,
          videoDuration: videoDuration,
        ),
      ),
    );
  }

  @override
  State<PromotionalLinksScreen> createState() => _PromotionalLinksScreenState();
}

class _PromotionalLinksScreenState extends State<PromotionalLinksScreen> {
  late List<LinkItemData> _links;

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.initialLinks);
  }

  void _openSpokeEditor({LinkItemData? existingLink, int? index}) async {
    if (existingLink == null && _links.length >= widget.maxLinks) {
      VayuSnackBar.showInfo(context, 'Maximum ${widget.maxLinks} links allowed.');
      return;
    }

    final result = await Navigator.push<LinkItemData>(
      context,
      MaterialPageRoute(
        builder: (_) => PromotionalLinkEditorScreen(
          initialLink: existingLink,
          videoDuration: widget.videoDuration,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (index != null && index >= 0 && index < _links.length) {
          _links[index] = result;
        } else {
          _links.add(result);
        }
      });
    }
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index);
    });
    VayuSnackBar.showInfo(context, 'Link removed');
  }

  void _saveAndClose() {
    widget.onSave(_links);
    Navigator.of(context).pop(_links);
  }

  IconData _getLinkIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.apk')) return Icons.android_rounded;
    if (lower.contains('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.contains('.zip')) return Icons.folder_zip_rounded;
    if (lower.contains('.docx') || lower.contains('.doc')) return Icons.description_rounded;
    return Icons.language_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promotional Links',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Visit Now (${_links.length}/${widget.maxLinks})',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          if (_links.isNotEmpty)
            TextButton(
              onPressed: _saveAndClose,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _links.isEmpty ? _buildEmptyState() : _buildLinksList(),
      bottomNavigationBar: _links.isNotEmpty
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderSecondary,
                      width: 0.5,
                    ),
                  ),
                ),
                child: AppButton(
                  onPressed: _saveAndClose,
                  label: 'Done',
                  variant: AppButtonVariant.primary,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No links added',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add links or files for viewers to visit.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: () => _openSpokeEditor(),
              label: 'Add link',
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinksList() {
    final canAddMore = _links.length < widget.maxLinks;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._links.asMap().entries.map((entry) {
          final index = entry.key;
          final link = entry.value;
          final icon = _getLinkIcon(link.url);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _openSpokeEditor(existingLink: link, index: index),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.borderSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              link.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                link.showAtSeconds > 0
                                    ? 'Appears at ${link.showAtSeconds}s'
                                    : 'From start (0s)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.textSecondary,
                        onPressed: () => _openSpokeEditor(existingLink: link, index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: AppColors.error,
                        onPressed: () => _removeLink(index),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (canAddMore)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: AppButton(
              onPressed: () => _openSpokeEditor(),
              label: '+ Add Link',
              variant: AppButtonVariant.outline,
            ),
          ),
      ],
    );
  }
}

/// **PromotionalLinkEditorScreen (Spoke Screen)**
///
/// Dedicated focused sub-screen for configuring a single promotional link.
/// Gives full focus without visual clutter or cramped keyboard behavior.
class PromotionalLinkEditorScreen extends StatefulWidget {
  final LinkItemData? initialLink;
  final double videoDuration;

  const PromotionalLinkEditorScreen({
    super.key,
    this.initialLink,
    this.videoDuration = 0.0,
  });

  @override
  State<PromotionalLinkEditorScreen> createState() => _PromotionalLinkEditorScreenState();
}

class _PromotionalLinkEditorScreenState extends State<PromotionalLinkEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  int _showAtSeconds = 0;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _attachedFileName;
  String? _attachedFileSize;
  CancelToken? _cancelToken;

  int _selectedTab = 0; // 0 = Web Link, 1 = File Attachment

  @override
  void initState() {
    super.initState();
    final link = widget.initialLink;
    _titleController = TextEditingController(text: link?.title ?? '');
    _urlController = TextEditingController(text: link?.url ?? '');
    final int maxSec = widget.videoDuration > 0 ? widget.videoDuration.floor() : 120;
    _showAtSeconds = link?.showAtSeconds ?? 0;
    if (maxSec > 0 && _showAtSeconds > maxSec) {
      _showAtSeconds = maxSec;
    }

    if (link != null && link.url.isNotEmpty) {
      final uri = Uri.tryParse(link.url);
      final lastPath = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final lower = lastPath.toLowerCase();
      if (lower.endsWith('.apk') ||
          lower.endsWith('.pdf') ||
          lower.endsWith('.zip') ||
          lower.endsWith('.docx') ||
          lower.endsWith('.txt')) {
        _attachedFileName = lastPath;
        _selectedTab = 1;
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Screen closed');
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'apk',
          'pdf',
          'zip',
          'doc',
          'docx',
          'txt',
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
        _isUploading = true;
        _uploadProgress = 0.0;
        _cancelToken = cancelToken;
      });

      final uploadResult = await ResourceUploadService().uploadResource(
        file: file,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _urlController.text = uploadResult.url;
          _attachedFileName = uploadResult.fileName;
          _attachedFileSize = uploadResult.formattedSize;

          if (_titleController.text.trim().isEmpty) {
            final fileName = uploadResult.fileName;
            final ext = fileName.contains('.')
                ? fileName.split('.').last.toUpperCase()
                : '';
            final baseName = fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;
            _titleController.text = ext.isNotEmpty ? '$baseName ($ext)' : baseName;
          }
        });
        VayuSnackBar.showSuccess(context, 'File uploaded and attached successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        VayuSnackBar.showError(context, 'Upload error: $e');
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFileName = null;
      _attachedFileSize = null;
      _urlController.clear();
    });
  }

  void _testUrl() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      VayuSnackBar.showError(context, 'Please enter a URL first.');
      return;
    }
    String formatted = raw;
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        VayuSnackBar.showError(context, 'Could not open URL: $formatted');
      }
    }
  }

  void _applyAndPop() {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      VayuSnackBar.showError(
        context,
        _selectedTab == 1 ? 'Please attach a file first.' : 'Please enter a URL.',
      );
      return;
    }

    String formattedUrl = rawUrl;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final validation = UrlUtils.validateUrl(formattedUrl);
    if (!validation.isValid) {
      VayuSnackBar.showError(context, validation.userMessage);
      return;
    }

    final effectiveTitle = UrlUtils.formatShortDomain(formattedUrl);

    final int maxSec = widget.videoDuration > 0 ? widget.videoDuration.floor() : 120;
    final result = LinkItemData(
      url: formattedUrl,
      title: effectiveTitle,
      showAtSeconds: _showAtSeconds.clamp(0, maxSec > 0 ? maxSec : 120),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialLink != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Promotion Link' : 'Add Promotion Link',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _applyAndPop,
            child: const Text(
              'Apply',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Tab Selector (Web Link vs File Attachment)
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.language_rounded,
                              size: 16,
                              color: _selectedTab == 0 ? Colors.white : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Web Link',
                              style: TextStyle(
                                color: _selectedTab == 0 ? Colors.white : AppColors.textTertiary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 16,
                              color: _selectedTab == 1 ? Colors.white : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'File Attachment',
                              style: TextStyle(
                                color: _selectedTab == 1 ? Colors.white : AppColors.textTertiary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tab 0: Web Link
            if (_selectedTab == 0) ...[
              Text(
                'Website URL',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://example.com/product',
                  prefixIcon: const Icon(Icons.link_rounded, size: 20, color: AppColors.textTertiary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Test Link',
                    onPressed: _testUrl,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSecondary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ] else ...[
              // Tab 1: File Attachment
              Text(
                'File attachment',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_attachedFileName != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_present_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachedFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (_attachedFileSize != null)
                              Text(
                                _attachedFileSize!,
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.error,
                        onPressed: _removeAttachment,
                      ),
                    ],
                  ),
                ),
              ] else if (_isUploading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        backgroundColor: AppColors.backgroundTertiary,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading file (${(_uploadProgress * 100).toInt()}%)…',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: _pickAndUploadFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderSecondary,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:  [
                          Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Upload file (max 200MB)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // Button Title (Call to Action)
            Text(
              'Button label',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Visit Now (default)',
                prefixIcon: const Icon(Icons.title_rounded, size: 20, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderSecondary.withValues(alpha: 0.5)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Timing (Show at seconds)
            Text(
              'Timing',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final int maxSec = widget.videoDuration > 0 ? widget.videoDuration.floor() : 120;
                final double sliderMax = maxSec > 0 ? maxSec.toDouble() : 1.0;
                final int divisions = maxSec > 0 ? maxSec : 1;
                final int clampedSeconds = _showAtSeconds.clamp(0, maxSec > 0 ? maxSec : 120);

                final quickSeconds = [0, 5, 10, 15, 30, 60].where((s) => s <= maxSec).toList();
                if (maxSec > 0 && !quickSeconds.contains(maxSec) && maxSec <= 120) {
                  quickSeconds.add(maxSec);
                  quickSeconds.sort();
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSecondary.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            clampedSeconds == 0
                                ? 'From start (0s)'
                                : 'Appears after ${clampedSeconds}s${widget.videoDuration > 0 ? ' (Video: ${maxSec}s)' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${clampedSeconds}s',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: clampedSeconds.toDouble().clamp(0.0, sliderMax),
                        min: 0,
                        max: sliderMax,
                        divisions: divisions,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.backgroundTertiary,
                        onChanged: maxSec <= 0
                            ? null
                            : (val) {
                                setState(() {
                                  _showAtSeconds = val.round().clamp(0, maxSec);
                                });
                              },
                      ),
                      if (quickSeconds.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children: quickSeconds.map((s) {
                            final selected = clampedSeconds == s;
                            return ChoiceChip(
                              label: Text('${s}s'),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.backgroundTertiary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _showAtSeconds = s.clamp(0, maxSec)),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 36),

            // Apply Button
            AppButton(
              onPressed: _isUploading ? null : _applyAndPop,
              label: isEditing ? 'Save' : 'Add link',
              variant: AppButtonVariant.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
