import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/managers/smart_cache_manager.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class UpiSetupDialog extends StatefulWidget {
  final String? initialUpiId;
  final ValueChanged<String> onSaved;

  const UpiSetupDialog({
    super.key,
    this.initialUpiId,
    required this.onSaved,
  });

  static Future<bool> ensureUpiAvailable(BuildContext context) async {
    final authService = AuthService();
    final userData = await authService.getUserData();
    String? existingUpi;
    if (userData case final Map<String, dynamic> userMap) {
      final paymentDetails = userMap['paymentDetails'];
      if (paymentDetails is Map) {
        existingUpi = paymentDetails['upiId']?.toString();
      }
    }

    if (existingUpi != null && existingUpi.trim().isNotEmpty) {
      return true;
    }

    // Direct check from creator payout profile in case user cache was not yet refreshed
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final response = await httpClientService.get(
          Uri.parse('${AppConfig.baseUrl}/api/creator-payouts/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final pDetails = data['paymentDetails'];
          if (pDetails is Map && pDetails['upiId'] != null) {
            final upi = pDetails['upiId'].toString().trim();
            if (upi.isNotEmpty) {
              try {
                final prefs = await SharedPreferences.getInstance();
                final fallbackUser = prefs.getString('fallback_user');
                if (fallbackUser != null) {
                  final uData = jsonDecode(fallbackUser);
                  uData['paymentDetails'] = {'upiId': upi};
                  await prefs.setString('fallback_user', jsonEncode(uData));
                }
              } catch (_) {}
              return true;
            }
          }
        }
      }
    } catch (_) {}

    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusSheet,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: UpiSetupDialog(
          onSaved: (_) => Navigator.pop(ctx, true),
        ),
      ),
    );

    return result == true;
  }

  @override
  State<UpiSetupDialog> createState() => _UpiSetupDialogState();
}

class _UpiSetupDialogState extends State<UpiSetupDialog> {
  late final TextEditingController _upiController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController(text: widget.initialUpiId ?? '');
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  bool _isValidUpi(String upi) {
    return RegExp(r'^[\w.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(upi.trim());
  }

  Future<void> _saveUpi() async {
    final upi = _upiController.text.trim();
    if (upi.isEmpty) {
      setState(() => _error = 'Enter your UPI ID');
      return;
    }

    if (!_isValidUpi(upi)) {
      setState(() => _error = 'Invalid UPI ID format');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await httpClientService.put(
        Uri.parse('${AppConfig.baseUrl}/api/creator-payouts/payment-method'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'paymentMethod': 'upi',
          'paymentDetails': {'upiId': upi},
          'country': 'IN',
        }),
      );

      if (response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final fallbackUser = prefs.getString('fallback_user');
          if (fallbackUser != null) {
            final uData = jsonDecode(fallbackUser);
            uData['paymentDetails'] = {'upiId': upi};
            await prefs.setString('fallback_user', jsonEncode(uData));
          }
          await SmartCacheManager().clearCacheByPattern('user_profile_');
        } catch (_) {}

        widget.onSaved(upi);
        if (mounted) {
          VayuSnackBar.showSuccess(context, 'UPI ID saved');
        }
      } else {
        setState(() => _error = 'Failed to save UPI ID');
      }
    } catch (e) {
      setState(() => _error = 'Error saving UPI: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space24,
          vertical: AppSpacing.space16,
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
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.vSpace16,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add UPI ID',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  splashRadius: 22,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTargetApple,
                    minHeight: AppSpacing.minTouchTargetApple,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            AppSpacing.vSpace4,
            Text(
              'Receive earnings on the 1st of every month.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            AppSpacing.vSpace16,
            TextField(
              controller: _upiController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'name@okhdfcbank',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                errorText: _error,
                filled: true,
                fillColor: AppColors.backgroundPrimary,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                  vertical: AppSpacing.space12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            AppSpacing.vSpace24,
            AppButton(
              onPressed: _isSaving ? null : _saveUpi,
              isLoading: _isSaving,
              label: 'Save UPI',
              variant: AppButtonVariant.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
