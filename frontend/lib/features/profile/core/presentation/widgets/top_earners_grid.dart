import 'dart:convert';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/radius.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/features/profile/core/presentation/screens/profile_screen.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/app_button.dart';

/// Compact grid (3 columns) showing top creators from the user's following list.
/// This reuses the same API as `TopEarnersBottomSheet` but is optimised for the
/// ProfileScreen "Recommendations" tab.
class TopEarnersGrid extends StatefulWidget {
  const TopEarnersGrid({super.key});

  @override
  State<TopEarnersGrid> createState() => _TopEarnersGridState();
}

class _TopEarnersGridState extends State<TopEarnersGrid> {
  List<Map<String, dynamic>> _topCreators = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTopCreators();
  }

  Future<void> _loadTopCreators() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Sign in to see top creators.';
          _isLoading = false;
        });
        return;
      }

      final baseUrl = await AppConfig.getBaseUrlWithFallback();
      final uri = Uri.parse('$baseUrl/api/users/top-earners-from-following');

      AppLogger.log('💰 TopCreatorsGrid: Fetching top creators from $uri');

      final response = await httpClientService.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        timeout: const Duration(seconds: 30),
      );

      AppLogger.log(
          '💰 TopCreatorsGrid: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final topCreators =
            List<Map<String, dynamic>>.from(data['topEarners'] ?? []);

        setState(() {
          _topCreators = topCreators;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load top creators (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.log('❌ TopCreatorsGrid: Error loading top creators: $e');
      AppLogger.log('❌ TopCreatorsGrid: Stack trace: $stackTrace');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timeout. Please check your connection.'
            : e.toString().contains('SocketException')
                ? 'Network error. Please check your internet connection.'
                : 'Failed to load top creators';
        _isLoading = false;
      });
    }
  }

  void _navigateToUserProfile(String userId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.textTertiary.withValues(alpha: 0.8),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Failed to load top creators',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                onPressed: _loadTopCreators,
                label: 'Retry',
                variant: AppButtonVariant.secondary,
              ),
            ],
          ),
        ),
      );
    }

    if (_topCreators.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                'No creators yet',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Creators you follow will appear here',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // LIST: Clean Apple-style list prioritizing whitespace over borders & containers
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing4,
        vertical: AppSpacing.spacing2,
      ),
      itemCount: _topCreators.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final creator = _topCreators[index];
        return _buildCreatorListItem(creator, index + 1);
      },
    );
  }

  Widget _buildCreatorListItem(Map<String, dynamic> creator, int rank) {
    final userId = creator['userId'] as String?;
    final name = creator['name'] as String? ?? 'Unknown';
    final profilePic = creator['profilePic'] as String?;
    final score = (creator['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final videoCount = (creator['videoCount'] as num?)?.toInt() ?? 0;

    String subtitleText = '';
    if (videoCount > 0) {
      subtitleText = '$videoCount ${videoCount == 1 ? 'video' : 'videos'}';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: userId != null ? () => _navigateToUserProfile(userId) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              // Typographic Rank - Clean Apple style (no colored circle badge or shadows)
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    color: rank <= 3 ? AppColors.textPrimary : AppColors.textTertiary,
                    fontWeight: rank <= 3 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Clean Avatar with subtle hairline ring
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: ClipOval(
                  child: profilePic != null && profilePic.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profilePic,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.backgroundSecondary,
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.backgroundSecondary,
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.backgroundSecondary,
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Creator Name & Meta with spacious negative space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Minimal Score (if available) - calm typography without neon tags
              if (score > 0) ...[
                const SizedBox(width: 8),
                Text(
                  _formatScore(score),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary.withValues(alpha: 0.35),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatScore(double score) {
    if (score >= 10000000) {
      return '${(score / 10000000).toStringAsFixed(1)} Cr';
    } else if (score >= 100000) {
      return '${(score / 100000).toStringAsFixed(1)} L';
    } else if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    } else {
      return score.toStringAsFixed(0);
    }
  }
}
