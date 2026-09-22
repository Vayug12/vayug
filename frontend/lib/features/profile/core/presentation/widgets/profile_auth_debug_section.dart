import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

/// Debug-only section for testing token expiration and session recovery scenarios.
/// Only rendered in debug mode and when viewing the user's own profile.
class ProfileAuthDebugSection extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onRefresh;

  const ProfileAuthDebugSection({
    super.key,
    required this.authService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.amber, size: 14),
              SizedBox(width: 6),
              Text(
                'AUTH DEBUG TOOLS (debug only)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // --- Case 1: Normal Expiry ---
          _buildDebugButton(
            context,
            icon: Icons.timer_off_outlined,
            label: 'Case 1: Expire Access Token',
            subtitle: 'Refresh token intact → should silently recover',
            color: Colors.amber[700]!,
            onPressed: () async {
              await authService.debugExpireToken();
              if (!context.mounted) return;
              VayuSnackBar.showInfo(
                context,
                'Case 1: Access token expired. Watch logs for silent refresh...',
              );
              onRefresh();
            },
          ),
          const SizedBox(height: 6),

          // --- Case 2: Full Session Loss ---
          _buildDebugButton(
            context,
            icon: Icons.no_encryption_outlined,
            label: 'Case 2: Full Session Loss',
            subtitle: 'Both tokens gone → should show "Session Expired" screen',
            color: Colors.red[700]!,
            onPressed: () async {
              await authService.debugFullSessionLoss();
              if (!context.mounted) return;
              VayuSnackBar.showInfo(
                context,
                'Case 2: Both tokens deleted. Watch for sign-in screen...',
              );
              onRefresh();
            },
          ),
          const SizedBox(height: 6),

          // --- Case 3: Rotation Mismatch ---
          _buildDebugButton(
            context,
            icon: Icons.sync_problem_outlined,
            label: 'Case 3: Rotation Mismatch',
            subtitle:
                'Corrupt refresh token → backend rejects, Google fallback tested',
            color: Colors.deepOrange[700]!,
            onPressed: () async {
              await authService.debugRotationMismatch();
              if (!context.mounted) return;
              VayuSnackBar.showInfo(
                context,
                'Case 3: Refresh token corrupted (stale). Watch for Google Silent Sign-In fallback...',
              );
              onRefresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
