import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/ads/data/services/ad_refresh_notifier.dart';
import 'package:vayug/features/ads/data/services/ad_service.dart';
import 'package:vayug/features/ads/data/services/wallet_service.dart';
import 'package:vayug/features/ads/data/wallet_model.dart';
import 'package:vayug/features/ads/presentation/widgets/wallet/top_up_sheet.dart';
import 'package:vayug/shared/services/cloudflare_r2_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class _AdPlan {
  final String id;
  final String title;
  final int price;
  final int credits;
  final int durationDays;

  const _AdPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.credits,
    required this.durationDays,
  });

  String getViewsText(String format) {
    if (format == 'photo') {
      return credits == 30 ? '~1,500 Views' : '~5,000 Views';
    } else {
      return credits == 30 ? '~1,000 Views' : '~3,333 Views';
    }
  }
}

const _kPlans = [
  _AdPlan(
    id: 'starter',
    title: 'Starter',
    price: 49,
    credits: 30,
    durationDays: 7,
  ),
  _AdPlan(
    id: 'popular',
    title: 'Popular',
    price: 149,
    credits: 100,
    durationDays: 14,
  ),
];

class CreateAdScreenRefactored extends ConsumerStatefulWidget {
  const CreateAdScreenRefactored({super.key});

  @override
  ConsumerState<CreateAdScreenRefactored> createState() =>
      _CreateAdScreenRefactoredState();
}

class _CreateAdScreenRefactoredState
    extends ConsumerState<CreateAdScreenRefactored> {
  final _headlineController = TextEditingController();
  final _linkController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _cloudflare = CloudflareR2Service();

  _AdPlan _selectedPlan = _kPlans[0];
  String _format = 'photo'; // 'photo' or 'video'
  File? _mediaFile;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _headlineController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      HapticFeedback.lightImpact();
      if (_format == 'photo') {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (picked != null) {
          setState(() {
            _mediaFile = File(picked.path);
            _errorMessage = null;
          });
        }
      } else {
        final picked = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
        if (picked != null) {
          setState(() {
            _mediaFile = File(picked.path);
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      AppLogger.log('Media pick error: $e');
    }
  }

  void _clearMedia() {
    HapticFeedback.lightImpact();
    setState(() {
      _mediaFile = null;
    });
  }

  String _formatDestinationUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  bool _validate() {
    if (_mediaFile == null) {
      setState(() => _errorMessage =
          _format == 'photo' ? 'Select a photo' : 'Select a video');
      return false;
    }
    if (_headlineController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Add a headline');
      return false;
    }
    if (_linkController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Add a destination link');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _handleLaunch() async {
    if (_isLoading) return;
    if (!_validate()) return;

    HapticFeedback.lightImpact();
    int currentBalance = 0;
    try {
      final w = await ref.read(walletServiceProvider).getBalance();
      currentBalance = w.balance;
    } catch (_) {
      final w = ref.read(adWalletProvider).asData?.value;
      currentBalance = w?.balance ?? 0;
    }

    final requiredCredits = _selectedPlan.credits;

    if (currentBalance < requiredCredits) {
      final shortfall = requiredCredits - currentBalance;
      if (!mounted) return;
      final credited = await TopUpSheet.show(context, shortfall: shortfall);
      if (!credited || !mounted) return;
      ref.invalidate(adWalletProvider);
    }

    await _publishAd();
  }

  Future<void> _publishAd() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? imageUrl;
      String? videoUrl;

      if (_format == 'photo') {
        imageUrl = await _cloudflare.uploadImage(_mediaFile!);
      } else {
        final res = await _cloudflare.uploadVideoForAd(_mediaFile!);
        videoUrl = res['url'] ?? res['hls_urls']?['hls_stream'];
        if (videoUrl == null || videoUrl.isEmpty) {
          throw Exception('Video upload failed');
        }
      }

      final idempotencyKey =
          '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
      final now = DateTime.now();

      final result = await ref.read(adServiceProvider).createAdWithCredits(
            idempotencyKey: idempotencyKey,
            title: _headlineController.text.trim(),
            description: _headlineController.text.trim(),
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            link: _formatDestinationUrl(_linkController.text),
            adType: _format == 'photo' ? 'banner' : 'video feed',
            budget: _selectedPlan.credits.toDouble(),
            startDate: now,
            endDate: now.add(Duration(days: _selectedPlan.durationDays)),
          );

      if (result['success'] == true) {
        ref.invalidate(adWalletProvider);
        AdRefreshNotifier().notifyRefresh();
        if (mounted) {
          VayuSnackBar.showSuccess(context, 'Ad launched');
          Navigator.of(context).pop();
        }
      } else {
        throw Exception(result['message'] ?? 'Could not create ad');
      }
    } on InsufficientCreditsException catch (e) {
      if (mounted) {
        final credited =
            await TopUpSheet.show(context, shortfall: e.shortfall);
        if (credited && mounted) {
          ref.invalidate(adWalletProvider);
          await _publishAd();
        }
      }
    } catch (e) {
      AppLogger.log('Ad creation failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showViewsCalculationSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderPrimary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Views Calculation',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              Text(
                '1 Credit = ₹1 Ad Spend (CPM = Cost per 1,000 views)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildCalculationCard(
                icon: Icons.image_outlined,
                title: 'Photo Ads',
                cpm: '₹20 CPM',
                rateText: '1 Credit = 50 Views',
                tiers: const [
                  {'pack': '30 Credits (₹49)', 'views': '1,500 Views'},
                  {'pack': '100 Credits (₹149)', 'views': '5,000 Views'},
                ],
              ),
              const SizedBox(height: 12),
              _buildCalculationCard(
                icon: Icons.videocam_outlined,
                title: 'Video Ads',
                cpm: '₹30 CPM',
                rateText: '1 Credit ≈ 33.3 Views',
                tiers: const [
                  {'pack': '30 Credits (₹49)', 'views': '1,000 Views'},
                  {'pack': '100 Credits (₹149)', 'views': '3,333 Views'},
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfacePrimary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: AppColors.borderPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalculationCard({
    required IconData icon,
    required String title,
    required String cpm,
    required String rateText,
    required List<Map<String, String>> tiers,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rateText,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cpm,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: AppColors.borderPrimary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),
          for (final tier in tiers) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tier['pack']!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    tier['views']!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(adWalletProvider);
    final walletBalance = walletAsync.asData?.value.balance ?? 0;
    final hasEnoughCredits = walletBalance >= _selectedPlan.credits;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New Ad',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                TopUpSheet.show(context);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.borderPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$walletBalance Credits',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Plan',
                      onInfoTap: () => _showViewsCalculationSheet(context),
                    ),
                    const SizedBox(height: 12),
                    _buildPlans(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Creative'),
                    const SizedBox(height: 12),
                    _buildFormatToggle(),
                    const SizedBox(height: 12),
                    _buildMediaBox(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Destination'),
                    const SizedBox(height: 12),
                    _buildInputs(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBox(_errorMessage!),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomBar(hasEnoughCredits),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onInfoTap}) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onInfoTap != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onInfoTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlans() {
    return Row(
      children: [
        for (int i = 0; i < _kPlans.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _buildPlanCard(_kPlans[i])),
        ],
      ],
    );
  }

  Widget _buildPlanCard(_AdPlan plan) {
    final isSelected = _selectedPlan.id == plan.id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedPlan = plan);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.borderPrimary.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.title,
                  style: AppTypography.labelLarge.copyWith(
                    color:
                        isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${plan.price}',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.credits} Credits',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              plan.getViewsText(_format),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatToggle() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleTab('Photo', 'photo')),
          Expanded(child: _buildToggleTab('Video', 'video')),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String label, String value) {
    final isSelected = _format == value;
    return GestureDetector(
      onTap: () {
        if (_format != value) {
          HapticFeedback.lightImpact();
          setState(() {
            _format = value;
            _mediaFile = null;
            _errorMessage = null;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.backgroundPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBox() {
    const height = 180.0;
    if (_mediaFile != null) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_format == 'photo')
                Image.file(_mediaFile!, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _clearMedia,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _pickMedia,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderPrimary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _format == 'photo'
                  ? Icons.image_outlined
                  : Icons.videocam_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              _format == 'photo' ? 'Select photo' : 'Select video',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        TextField(
          controller: _headlineController,
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Headline',
            hintStyle:
                AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfacePrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _linkController,
          keyboardType: TextInputType.url,
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle:
                AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfacePrimary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Text(
      message,
      style: AppTypography.labelMedium.copyWith(color: AppColors.error),
    );
  }

  Widget _buildBottomBar(bool hasEnoughCredits) {
    final label = hasEnoughCredits
        ? 'Launch Ad'
        : 'Pay ₹${_selectedPlan.price} & Launch';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(
          top: BorderSide(
            color: AppColors.borderPrimary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLaunch,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
