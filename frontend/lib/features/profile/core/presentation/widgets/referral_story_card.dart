import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';

class ReferralStoryCard extends StatelessWidget {
  final String creatorName;
  final String? profilePicUrl;
  final String? referralCode;
  final double width;
  final double height;

  const ReferralStoryCard({
    super.key,
    required this.creatorName,
    this.profilePicUrl,
    this.referralCode,
    this.width = 300,
    this.height = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Top Bar: Apple-style Minimal Wordmark (duplicate CREATOR badge removed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VAYUG',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),

          // 2. Creator Profile Section
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            creatorName.isNotEmpty ? creatorName : 'Vayug Creator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creator on Vayug',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 20,
            thickness: 1,
          ),

          // 3. Direct Features List (Apple Card style with squircle icon chips)
          Column(
            children: [
              _buildFeatureRow(
                icon: HugeIcons.strokeRoundedMoney04,
                title: 'Day 1 monetization',
                subtitle: 'Monetize from your very first video',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                icon: HugeIcons.strokeRoundedLink01,
                title: 'Link below every video',
                subtitle: 'Direct store & bio link conversion',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                icon: HugeIcons.strokeRoundedShield01,
                title: 'Private E2EE videos',
                subtitle: 'Encrypted exclusive subscriber content',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                icon: HugeIcons.strokeRoundedFlash,
                title: 'Instant UPI payouts',
                subtitle: 'Revenue sent directly to your bank',
              ),
            ],
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 20,
            thickness: 1,
          ),

          // 4. Bottom Footer: Referral Code + Store Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (referralCode != null && referralCode!.isNotEmpty)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Code: $referralCode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Google Play Store',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatarContent;
    if (profilePicUrl != null && profilePicUrl!.isNotEmpty) {
      if (profilePicUrl!.startsWith('http')) {
        avatarContent = Image.network(
          profilePicUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatarIcon(),
        );
      } else {
        avatarContent = Image.file(
          File(profilePicUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatarIcon(),
        );
      }
    } else {
      avatarContent = _fallbackAvatarIcon();
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: avatarContent,
      ),
    );
  }

  Widget _fallbackAvatarIcon() {
    return Container(
      color: AppColors.surfaceSecondary,
      alignment: Alignment.center,
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        color: AppColors.textSecondary,
        size: 22,
      ),
    );
  }

  Widget _buildFeatureRow({
    required dynamic icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
