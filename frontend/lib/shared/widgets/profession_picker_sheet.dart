import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/models/profession.dart';
import 'package:vayug/shared/services/profession_catalog_service.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';

class ProfessionPickerSheet {
  const ProfessionPickerSheet._();

  static Future<List<String>?> show({
    required BuildContext context,
    required Iterable<String> initialSelection,
    required bool multiSelect,
    String? title,
    String? emptySelectionLabel,
  }) {
    return VayuBottomSheet.show<List<String>>(
      context: context,
      title: title ??
          AppText.get('profession_picker_title', fallback: 'Choose profession'),
      icon: Icons.work_outline_rounded,
      useDraggable: true,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (context, scrollController) => _ProfessionPickerBody(
        initialSelection: initialSelection.toSet(),
        multiSelect: multiSelect,
        emptySelectionLabel: emptySelectionLabel ??
            AppText.get('profession_everyone', fallback: 'Everyone'),
        scrollController: scrollController,
      ),
    );
  }
}

class _ProfessionPickerBody extends StatefulWidget {
  final Set<String> initialSelection;
  final bool multiSelect;
  final String emptySelectionLabel;
  final ScrollController? scrollController;

  const _ProfessionPickerBody({
    required this.initialSelection,
    required this.multiSelect,
    required this.emptySelectionLabel,
    this.scrollController,
  });

  @override
  State<_ProfessionPickerBody> createState() => _ProfessionPickerBodyState();
}

class _ProfessionPickerBodyState extends State<_ProfessionPickerBody> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final Set<String> _selected = {...widget.initialSelection};

  List<Profession>? _professions;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchChanged);
    _loadProfessions();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadProfessions({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ProfessionCatalogService.instance.getProfessions(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _professions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _select(Profession profession) {
    HapticFeedback.selectionClick();
    if (!widget.multiSelect) {
      Navigator.pop(context, <String>[profession.id]);
      return;
    }
    setState(() {
      if (!_selected.add(profession.id)) {
        _selected.remove(profession.id);
      }
    });
  }

  void _selectEmptyOption() {
    HapticFeedback.selectionClick();
    if (!widget.multiSelect) {
      Navigator.pop(context, <String>[]);
      return;
    }
    setState(() {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              AppSpacing.vSpace12,
              Text(
                AppText.get('loading', fallback: 'Loading...'),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _professions == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.edgeInsetsAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
              AppSpacing.vSpace12,
              Text(
                AppText.get(
                  'profession_load_error',
                  fallback: 'Could not load professions. Please try again.',
                ),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              AppSpacing.vSpace16,
              AppButton(
                label: AppText.get('btn_retry', fallback: 'Retry'),
                variant: AppButtonVariant.secondary,
                onPressed: () => _loadProfessions(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    final query = _searchController.text.trim();
    final filteredProfessions = _professions!
        .where((profession) => profession.matches(query))
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // iOS HIG Search Bar
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.spacing4,
            vertical: AppSpacing.spacing1,
          ),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfacePrimary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: _searchFocusNode.hasFocus
                    ? AppColors.primary
                    : AppColors.borderSubtle,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                AppSpacing.hSpace8,
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    cursorColor: AppColors.primary,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: AppText.get(
                        'profession_search_hint',
                        fallback: 'Search profession',
                      ),
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _searchController.clear();
                      _searchFocusNode.requestFocus();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AppSpacing.vSpace8,

        // Selection / Search Results Header if multi-select
        if (widget.multiSelect && _selected.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.spacing4,
              vertical: AppSpacing.spacing1,
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_selected.length} selected',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selected.clear());
                  },
                  child: Text(
                    AppText.get('profession_clear_all', fallback: 'Clear all'),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // List View
        Expanded(
          child: filteredProfessions.isEmpty && query.isNotEmpty
              ? _buildEmptyState(query)
              : ListView.separated(
                  controller: widget.scrollController,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: filteredProfessions.length + (query.isEmpty ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 52,
                    endIndent: 16,
                    color: AppColors.separator,
                  ),
                  itemBuilder: (context, index) {
                    if (query.isEmpty && index == 0) {
                      final isSelected = _selected.isEmpty;
                      return _buildListTile(
                        icon: Icons.public_rounded,
                        label: widget.emptySelectionLabel,
                        isSelected: isSelected,
                        onTap: _selectEmptyOption,
                        isMultiSelect: widget.multiSelect,
                      );
                    }

                    final professionIndex = query.isEmpty ? index - 1 : index;
                    final profession = filteredProfessions[professionIndex];
                    final isSelected = _selected.contains(profession.id);

                    return _buildListTile(
                      icon: Icons.work_outline_rounded,
                      label: profession.label,
                      isSelected: isSelected,
                      onTap: () => _select(profession),
                      isMultiSelect: widget.multiSelect,
                    );
                  },
                ),
        ),

        // Bottom Done Action for Multi-select
        if (widget.multiSelect)
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.edgeInsetsAll16,
              child: AppButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, _selected.toList());
                },
                label: _selected.isEmpty
                    ? AppText.get('btn_done', fallback: 'Done')
                    : '${AppText.get('btn_done', fallback: 'Done')} (${_selected.length})',
                variant: AppButtonVariant.primary,
                isFullWidth: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isMultiSelect,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTargetApple,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.spacing4,
            vertical: AppSpacing.spacing3,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfacePrimary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.squircle),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                ),
              ),
              AppSpacing.hSpace12,
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              AppSpacing.hSpace8,
              if (isMultiSelect)
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary.withValues(alpha: 0.5),
                )
              else if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: AppSpacing.edgeInsetsAll24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            AppSpacing.vSpace12,
            Text(
              AppText.get(
                'profession_no_results',
                fallback: 'No professions found',
              ),
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vSpace4,
            Text(
              '"$query"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            AppSpacing.vSpace16,
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _searchController.clear();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  AppText.get('profession_clear_search', fallback: 'Clear search'),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


