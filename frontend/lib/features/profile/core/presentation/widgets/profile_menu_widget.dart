import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vayug/features/profile/core/presentation/managers/profile_state_manager.dart';
import 'package:vayug/shared/services/auto_scroll_settings.dart';
import 'package:vayug/features/profile/core/presentation/widgets/profile_dialogs_widget.dart';

import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';

import 'package:vayug/features/profile/core/presentation/screens/settings_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:vayug/features/profile/core/presentation/screens/edit_profile_screen.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class ProfileMenuWidget extends StatelessWidget {
  final ProfileStateManager stateManager;
  final String? userId;
  final VoidCallback? onEditProfile;
  final VoidCallback? onSaveProfile;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onReportUser;
  final VoidCallback? onShowWhatsApp;
  final VoidCallback? onShowFAQ;
  final VoidCallback? onShowFeedback;
  final VoidCallback? onEnterSelectionMode;
  final VoidCallback? onLogout;
  final VoidCallback? onGoogleSignIn;
  final Future<bool> Function()? onCheckPaymentSetupStatus;

  const ProfileMenuWidget({
    super.key,
    required this.stateManager,
    this.userId,
    this.onEditProfile,
    this.onSaveProfile,
    this.onCancelEdit,
    this.onReportUser,
    this.onShowWhatsApp,
    this.onShowFAQ,
    this.onShowFeedback,
    this.onEnterSelectionMode,
    this.onLogout,
    this.onGoogleSignIn,
    this.onCheckPaymentSetupStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundPrimary,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          border: Border(
            left: BorderSide(
              color: AppColors.borderPrimary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Consumer<ProfileStateManager>(
            builder: (context, stateManager, child) {
              // 1. Account & Creator Group
              final List<_DrawerMenuItem> accountItems = [
                if (!stateManager.isEditing)
                  _DrawerMenuItem(
                    title: 'Edit Profile',
                    icon: HugeIcons.strokeRoundedUser,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            stateManager: stateManager,
                          ),
                        ),
                      );
                      onEditProfile?.call();
                    },
                  )
                else ...[
                  _DrawerMenuItem(
                    title: 'Save',
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      onSaveProfile?.call();
                    },
                  ),
                  _DrawerMenuItem(
                    title: 'Cancel',
                    icon: HugeIcons.strokeRoundedCancel01,
                    onTap: () {
                      Navigator.pop(context);
                      onCancelEdit?.call();
                    },
                  ),
                ],
                if (stateManager.isOwner)
                  _DrawerMenuItem(
                    title: 'Manage Content',
                    icon: HugeIcons.strokeRoundedDelete02,
                    onTap: () {
                      Navigator.pop(context);
                      onEnterSelectionMode?.call();
                    },
                  ),
                if (stateManager.isOwner && stateManager.hasUpiId)
                  _DrawerMenuItem(
                    title: 'Setup Billing',
                    icon: HugeIcons.strokeRoundedWallet01,
                    onTap: () {
                      Navigator.pop(context);
                      ProfileDialogsWidget.showHowToEarnDialog(
                        context,
                        stateManager: stateManager,
                      );
                    },
                  ),
              ];

              // 2. Preferences & Settings Group
              final List<_DrawerMenuItem> preferenceItems = [
                _DrawerMenuItem(
                  title: 'Settings',
                  icon: HugeIcons.strokeRoundedSettings02,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _DrawerMenuItem(
                  title: 'Auto Scroll',
                  icon: HugeIcons.strokeRoundedScrollVertical,
                  onTap: () async {
                    final enabled = await AutoScrollSettings.isEnabled();
                    await AutoScrollSettings.setEnabled(!enabled);
                    if (context.mounted) {
                      VayuSnackBar.showInfo(
                        context,
                        'Auto Scroll: ${!enabled ? 'ON' : 'OFF'}',
                        duration: const Duration(seconds: 1),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ];

              // 3. Support & Legal Group (Feedback, FAQ, Legal)
              final List<_DrawerMenuItem> supportAndLegalItems = [
                _DrawerMenuItem(
                  title: 'Support Chat',
                  icon: HugeIcons.strokeRoundedMessageQuestion,
                  onTap: () {
                    Navigator.pop(context);
                    onShowWhatsApp?.call();
                  },
                ),
                _DrawerMenuItem(
                  title: 'Help & FAQ',
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  onTap: () {
                    Navigator.pop(context);
                    onShowFAQ?.call();
                  },
                ),
                _DrawerMenuItem(
                  title: 'Feedback',
                  icon: HugeIcons.strokeRoundedIdea01,
                  onTap: () {
                    Navigator.pop(context);
                    onShowFeedback?.call();
                  },
                ),
                _DrawerMenuItem(
                  title: 'Legal',
                  icon: HugeIcons.strokeRoundedAgreement01,
                  onTap: () {
                    Navigator.pop(context);
                    ProfileDialogsWidget.showLegalBottomSheet(context);
                  },
                ),
              ];

              // 4. Session / Danger Zone Group
              final List<_DrawerMenuItem> sessionItems = [
                if (userId != null &&
                    ((stateManager.userData?['_id'] ??
                            stateManager.userData?['id'] ??
                            stateManager.userData?['googleId']) !=
                        userId))
                  _DrawerMenuItem(
                    title: 'Report',
                    icon: HugeIcons.strokeRoundedAlert01,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      onReportUser?.call();
                    },
                  ),
                _DrawerMenuItem(
                  title: 'Logout',
                  icon: HugeIcons.strokeRoundedLogout01,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    onLogout?.call();
                  },
                ),
              ];

              final groups = [
                accountItems,
                preferenceItems,
                supportAndLegalItems,
                sessionItems,
              ].where((g) => g.isNotEmpty).toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
                    child: Text(
                      'Menu',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  for (int i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _buildGroupContainer(groups[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<_DrawerMenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 52,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            _buildMenuItemRow(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItemRow(_DrawerMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    color: item.isDestructive
                        ? AppColors.error
                        : (item.color ?? AppColors.textSecondary),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: item.isDestructive
                        ? AppColors.error
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!item.isDestructive)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppColors.textTertiary.withValues(alpha: 0.35),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerMenuItem {
  final String title;
  final dynamic icon;
  final Color? color;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.title,
    required this.icon,
    this.color,
    this.isDestructive = false,
    required this.onTap,
  });
}
