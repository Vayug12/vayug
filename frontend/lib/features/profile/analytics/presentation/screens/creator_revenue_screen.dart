import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/ads/data/services/ad_service.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/features/auth/data/services/logout_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/auth_sign_in_prompt.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:vayug/features/profile/analytics/data/services/analytics_service.dart';
import 'package:vayug/features/profile/analytics/domain/models/analytics_models.dart';
import 'package:vayug/features/profile/analytics/presentation/widgets/analytics_widgets.dart';
import 'package:vayug/core/providers/profile_providers.dart';
import 'package:vayug/features/profile/core/presentation/screens/creator_tools_screen.dart';
import 'package:vayug/features/profile/analytics/presentation/screens/notification_performance_screen.dart';
import 'package:vayug/features/video/paid/data/services/paid_video_service.dart';

class CreatorRevenueScreen extends ConsumerStatefulWidget {
  const CreatorRevenueScreen({super.key});

  @override
  ConsumerState<CreatorRevenueScreen> createState() => _CreatorRevenueScreenState();
}

class _CreatorRevenueScreenState extends ConsumerState<CreatorRevenueScreen> {
  final AdService _adService = AdService();
  final AuthService _authService = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  Map<String, dynamic>? _revenueData;
  Map<String, dynamic>? _paidSalesData;
  CreatorAnalytics? _analytics;
  List<RemovedVideo> _removedVideos = [];
  
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await _authService.getUserData();
      if (userData case final Map<String, dynamic> userMap) {
        final userId = (userMap['googleId'] ?? userMap['id'] ?? '').toString();

        if (userId.isEmpty) {
          throw Exception('User ID not found. Please sign in again.');
        }

        await Future.wait([
          _fetchRevenueData(forceRefresh),
          _fetchPaidVideoSales(),
          _fetchAnalytics(userId),
          _fetchRemovedVideos(),
          // We'll use a local fetch method to handle the async gap correctly
          _fetchCreatorAlertStats(),
        ]);

        if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.log('❌ CreatorDashboard: Error loading data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to load dashboard data. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRevenueData(bool forceRefresh) async {
    try {
      final freshRevenueData = await _adService.getCreatorRevenueSummary(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() => _revenueData = freshRevenueData);
      }
    } catch (e) {
      AppLogger.log('⚠️ Engagement load failed: $e');
    }
  }

  Future<void> _fetchPaidVideoSales() async {
    try {
      final sales = await PaidVideoService.instance.getCreatorSales();
      if (mounted) {
        setState(() => _paidSalesData = sales);
      }
    } catch (e) {
      AppLogger.log('⚠️ Paid video sales load failed: $e');
    }
  }

  Future<void> _fetchAnalytics(String userId) async {
    try {
      final data = await _analyticsService.getCreatorAnalytics(userId);
      if (mounted) {
        setState(() => _analytics = data);
      }
    } catch (e) {
      AppLogger.log('⚠️ Analytics load failed: $e');
    }
  }

  Future<void> _fetchRemovedVideos() async {
    try {
      final data = await _analyticsService.getRemovedVideos();
      if (mounted) {
        setState(() => _removedVideos = data);
      }
    } catch (e) {
      AppLogger.log('⚠️ Removed videos load failed: $e');
    }
  }

  Future<void> _fetchCreatorAlertStats() async {
    // Assuming ProfileStateManager is available via a provider or similar
    // Since it's a ChangeNotifier, we might need to access it differently if not in a ProviderScope
    // For now, let's use the local manager if we can or just call the service directly
    try {
      final manager = ref.read(profileStateManagerProvider);
      await manager.fetchCreatorAlertStats();
    } catch (e) {
      AppLogger.log('⚠️ Alert stats load failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: const Text("Creator Dashboard"),
                centerTitle: true,
                floating: true,
                snap: true,
                elevation: 0,
                bottom: const TabBar(
                  tabs: [
                    Tab(text: "Engagement"),
                    Tab(text: "Analytics"),
                  ],
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                ),
                actions: [
                  IconButton(
                    onPressed: () => _loadAllData(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ];
          },
          body: FutureBuilder<Map<String, dynamic>?>(
            future: _authService.getUserData(),
            builder: (context, snapshot) {
              final isSignedIn = snapshot.hasData && snapshot.data != null;

              if (!isSignedIn) {
                return _buildLoginPrompt();
              }

              if (_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_errorMessage != null) {
                return _buildErrorView();
              }

              return TabBarView(
                children: [
                  _buildRevenueTab(),
                  _buildAnalyticsTab(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// No title: the app bar names the screen and the button names the action.
  Widget _buildLoginPrompt() {
    return AuthSignInPrompt(
      onSignedIn: () async {
        if (!mounted) return;
        await LogoutService.refreshAllState(ref);
        _loadAllData();
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            AppSpacing.vSpace16,
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
            AppSpacing.vSpace16,
            AppButton(onPressed: _loadAllData, label: "Retry"),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTab() {
    if (_revenueData == null) return const Center(child: Text("No engagement data available"));

    return RefreshIndicator(
      onRefresh: () => _loadAllData(forceRefresh: true),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.spacing4),
        child: Column(
          children: [
            _buildRevenueOverviewCard(),
            AppSpacing.vSpace24,
            _buildPaidVideoSalesCard(),
            AppSpacing.vSpace24,
            _buildRevenueBreakdownCard(),
            AppSpacing.vSpace24,
            _buildCreatorAlertsSection(),
            AppSpacing.vSpace24,
            _buildExportSubscribersSection(),
            if (_removedVideos.isNotEmpty) ...[
              AppSpacing.vSpace24,
              _buildRemovedVideosSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportSubscribersSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.spacing4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt, color: AppColors.primary),
              AppSpacing.hSpace8,
              Text("Your Audience", style: AppTypography.titleMedium),
            ],
          ),
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _isExporting ? null : _exportSubscribers,
              label: _isExporting ? "Exporting..." : "Export Subscribers (CSV)",
              icon: _isExporting ? null : const Icon(Icons.home),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSubscribers() async {
    setState(() => _isExporting = true);
    try {
      final data = await _analyticsService.exportSubscribers();
      final subscribers = List<Map<String, dynamic>>.from(data['subscribers'] ?? []);
      
      if (subscribers.isEmpty) {
        if (mounted) {
          VayuSnackBar.showInfo(context, 'No subscribers to export.');
        }
        return;
      }

      // Generate CSV
      final StringBuffer csv = StringBuffer();
      csv.writeln('Name,Email,SubscribedAt');
      for (final sub in subscribers) {
        final name = (sub['name'] ?? '').toString().replaceAll(',', ' ');
        final email = (sub['email'] ?? '').toString();
        final date = (sub['subscribedAt'] ?? '').toString();
        csv.writeln('$name,$email,$date');
      }

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/subscribers_export.csv');
      await file.writeAsString(csv.toString());

      // Share
      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Vayug Subscribers Export',
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ Failed to export subscribers: $e');
      if (mounted) {
        VayuSnackBar.showError(context, 'Failed to export subscribers: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildAnalyticsTab() {
    if (_analytics == null) return const Center(child: Text("No analytics data available"));

    return RefreshIndicator(
      onRefresh: () => _loadAllData(forceRefresh: true),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.spacing4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Core Analytics 2x3 Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.spacing3,
              mainAxisSpacing: AppSpacing.spacing3,
              childAspectRatio: 1.45,
              children: [
                AnalyticsStatCard(
                  label: "Total Views", 
                  value: _analytics!.core.totalViews.toString(), 
                  icon: Icons.visibility,
                  color: AppColors.primary,
                  growth: _analytics!.core.viewsGrowth,
                  onTap: _showViewsGuide,
                ),
                AnalyticsStatCard(
                  label: "Watch Time", 
                  value: "${_analytics!.core.totalWatchTime}m", 
                  icon: Icons.access_time,
                  color: Colors.orange,
                  growth: _analytics!.core.watchTimeGrowth,
                  onTap: _showWatchTimeGuide,
                ),
                AnalyticsStatCard(
                  label: "Visit Now Clicks", 
                  value: _analytics!.core.totalLinkClicks.toString(), 
                  icon: Icons.ads_click_rounded,
                  color: Colors.tealAccent,
                  onTap: _showLinkClicksGuide,
                ),
                AnalyticsStatCard(
                  label: "Shares", 
                  icon: Icons.share,
                  color: Colors.blue,
                  value: _analytics!.core.totalShares.toString(),
                  onTap: _showSharesGuide,
                ),
                AnalyticsStatCard(
                  label: "Skip Rate", 
                  value: "${(_analytics!.core.skipRate * 100).toStringAsFixed(1)}%", 
                  icon: Icons.skip_next,
                  color: Colors.redAccent,
                  onTap: _showSkipRateGuide,
                ),
                AnalyticsStatCard(
                  label: "Avg Watch Time", 
                  value: "${_analytics!.core.avgWatchDuration}s", 
                  icon: Icons.timelapse_rounded,
                  color: Colors.purpleAccent,
                  onTap: _showAvgWatchGuide,
                ),
              ],
            ),
            
            AppSpacing.vSpace24,
            PerformanceChart(
              data: _analytics!.dailyPerformance, 
              title: "Daily Performance",
              onTap: _showPerformanceGuide,
            ),
            
            AppSpacing.vSpace24,
            Text("Detailed Breakdown", style: AppTypography.titleMedium),
            AppSpacing.vSpace12,
            _buildSettingRow(
              icon: Icons.video_library_rounded,
              title: "Top Performing Videos",
              subtitle: "Rankings by views & engagement",
              trailing: Text(
                _analytics!.topVideos.isEmpty
                    ? 'None'
                    : '${_analytics!.topVideos.length} videos',
                style: TextStyle(
                  color: _analytics!.topVideos.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onTap: _showTopVideosSheet,
            ),
            _buildSettingRow(
              icon: Icons.pie_chart_outline_rounded,
              title: "Audience Insights",
              subtitle: "New vs returning & top locations",
              trailing: Text(
                '${_analytics!.audience.topLocations.length} states',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onTap: _showAudienceInsightsSheet,
            ),
            AppSpacing.vSpace24,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderPrimary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showSkipRateGuide() {
    _showGenericGuide(
      title: "Skip Rate Kya Hai?",
      icon: Icons.ads_click,
      content: "Ye pichle 14 dino ka data hai. Ye dikhata hai ki kitne % log aapka video bina dekhe turant agla video dekhne chale gaye. Har din naya data judta hai aur sabse purana (15th day) ka data hat jata hai.",
    );
  }

  void _showViewsGuide() {
    _showGenericGuide(
      title: "Total Views Kya Hai?",
      icon: Icons.visibility,
      content: "Ye pichle 14 dino mein aaye total views hain. Ye data rozana update hota hai: pichle 14 dino ka total dikhane ke liye purana data hat-ta rehta hai.",
    );
  }

  void _showWatchTimeGuide() {
    _showGenericGuide(
      title: "Watch Time Kya Hai?",
      icon: Icons.access_time,
      content: "Ye pichle 14 dino ka total Watch Time hai (minutes mein). Isse ye pata chalta hai ki pichle do hafton mein logon ne aapke content par kitna time bitaya.",
    );
  }

  void _showSharesGuide() {
    _showGenericGuide(
      title: "Shares Kya Hai?",
      icon: Icons.share,
      content: "Ye pichle 14 dino mein hue total shares ka count hai. Har din ye chart pichle 14 dino ki snapshot dikhata hai.",
    );
  }

  void _showLinkClicksGuide() {
    _showGenericGuide(
      title: "Visit Now Clicks Kya Hai?",
      icon: Icons.ads_click_rounded,
      content: "Ye pichle 14 dino mein aapke videos par 'Visit Now' button par hue total clicks ka count hai. Isse aap jaan sakte hain ki kitne viewers ne aapki website ya promotional links visit kiye.",
    );
  }

  void _showAvgWatchGuide() {
    _showGenericGuide(
      title: "Avg Watch Time Kya Hai?",
      icon: Icons.timelapse_rounded,
      content: "Ye aapke videos ka average watch duration (seconds mein) hai. Ye dikhata hai ki ek average viewer aapke video ko kitne second tak dekhta hai.",
    );
  }

  void _showPerformanceGuide() {
    _showGenericGuide(
      title: "Daily Performance Kya Hai?",
      icon: Icons.bar_chart,
      content: "Ye graph pichle 7 dino ki performance dikhata hai. Har ek bar ek din ko represent karta hai aur bar ki height ye dikhati hai ki us din kitne views aaye the.",
      secondaryButton: AppButton(
        onPressed: () {
          Navigator.pop(context);
          _showTopVideosSheet();
        },
        label: "View Top Videos",
        variant: AppButtonVariant.secondary,
        isFullWidth: true,
      ),
    );
  }

  void _showTopVideosSheet() {
    if (_analytics == null) return;
    
    VayuBottomSheet.show(
      context: context,
      title: "Top Performing Videos",
      icon: Icons.video_library_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_analytics!.topVideos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  "No videos uploaded in this period",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            )
          else ...[
            Text(
              "Ranked by views and engagement over the last 14 days.",
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            AppSpacing.vSpace16,
            ..._analytics!.topVideos.asMap().entries.map((entry) {
              final index = entry.key;
              final v = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderPrimary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.amber.withValues(alpha: 0.2)
                            : (index == 1
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (index == 2
                                    ? Colors.brown.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05))),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: index == 0
                              ? Colors.amber
                              : (index == 1
                                  ? Colors.grey[300]
                                  : (index == 2 ? Colors.brown[200] : AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    AppSpacing.hSpace12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.title.isNotEmpty ? v.title : 'Untitled Video',
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${v.views} views • ${v.shares} shares",
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 18),
                  ],
                ),
              );
            }).toList(),
          ],
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.pop(context),
              label: "Close",
            ),
          ),
          AppSpacing.vSpace16,
        ],
      ),
    );
  }

  void _showAudienceInsightsSheet() {
    if (_analytics == null) return;

    VayuBottomSheet.show(
      context: context,
      title: "Audience Insights",
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Viewer demographics and geographic distribution.",
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.vSpace16,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderPrimary.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("New vs Returning Viewers", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                AppSpacing.vSpace16,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat("New", _analytics!.audience.newVsReturning.newValue.toString()),
                    _buildMiniStat("Returning", _analytics!.audience.newVsReturning.returning.toString()),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.vSpace16,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderPrimary.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Top States", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                AppSpacing.vSpace12,
                ..._analytics!.audience.topLocations.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.name, style: AppTypography.bodyMedium),
                      Text("${l.value}%", style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.pop(context),
              label: "Close",
            ),
          ),
          AppSpacing.vSpace16,
        ],
      ),
    );
  }

  void _showGenericGuide({
    required String title,
    required IconData icon,
    required String content,
    List<Widget> items = const [],
    Widget? secondaryButton,
  }) {
    VayuBottomSheet.show(
      context: context,
      title: title,
      icon: icon,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4),
          ),
          if (items.isNotEmpty) ...[
            AppSpacing.vSpace24,
            ...items,
          ],
          AppSpacing.vSpace24,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.pop(context),
              label: "Samajh Gaya!",
            ),
          ),
          if (secondaryButton != null) ...[
            AppSpacing.vSpace12,
            secondaryButton,
          ],
          AppSpacing.vSpace16,
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildRevenueOverviewCard() {
    final thisMonth = (_revenueData?['thisMonth'] as num?)?.toDouble() ?? 0.0;
    final lastMonth = (_revenueData?['lastMonth'] as num?)?.toDouble() ?? 0.0;
    final lifetimeCreatorReward =
        (_revenueData?['totalRevenue'] as num?)?.toDouble() ??
        (_revenueData?['netRevenue'] as num?)?.toDouble() ??
        0.0;

    return Container(
      padding: EdgeInsets.all(AppSpacing.spacing5),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
              AppSpacing.hSpace8,
              Text("Lifetime Creator Reward", style: AppTypography.titleMedium),
            ],
          ),
          AppSpacing.vSpace12,
          // Main lifetime value
          Text(
            lifetimeCreatorReward.toStringAsFixed(2),
            style: AppTypography.displaySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
          ),
          AppSpacing.vSpace24,
          // This Month + Last Period
          Row(
            children: [
              Expanded(
                child: _buildRevenueStat("This Month", thisMonth.toStringAsFixed(2), Icons.calendar_month),
              ),
              Container(width: 1, height: 40, color: AppColors.borderPrimary),
              Expanded(
                child: _buildRevenueStat("Last Period", lastMonth.toStringAsFixed(2), Icons.history),
              ),
            ],
          ),
          AppSpacing.vSpace24,
          // Monthly Earnings button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showMonthlyEarningsSheet,
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text("View Monthly Earnings"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidVideoSalesCard() {
    final summary = _paidSalesData?['summary'] as Map<String, dynamic>?;
    final totalEarnings = (summary?['totalCreatorEarningsInr'] as num?)?.toDouble() ?? 0.0;
    final totalGross = (summary?['totalGrossRevenueInr'] as num?)?.toDouble() ?? 0.0;
    final totalUnlocks = (summary?['totalUnlocks'] as num?)?.toInt() ?? 0;
    final uniqueBuyers = (summary?['uniqueBuyersCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: EdgeInsets.all(AppSpacing.spacing5),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.squircle),
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              AppSpacing.hSpace8,
              Expanded(
                child: Text(
                  "Paid Video Sales",
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          AppSpacing.vSpace12,
          Text(
            "₹${totalEarnings.toStringAsFixed(2)}",
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.vSpace4,
          Text(
            "Gross: ₹${totalGross.toStringAsFixed(2)} · Settled 1st of month",
            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.vSpace16,
          Row(
            children: [
              Expanded(
                child: _buildRevenueStat("Total Unlocks", totalUnlocks.toString(), Icons.lock_open_rounded),
              ),
              Container(width: 1, height: 36, color: AppColors.borderPrimary),
              Expanded(
                child: _buildRevenueStat("Unique Buyers", uniqueBuyers.toString(), Icons.people_outline_rounded),
              ),
            ],
          ),
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showPaidVideoSalesSheet,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text("View Sales"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaidVideoSalesSheet() {
    final sales = (_paidSalesData?['sales'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final summary = _paidSalesData?['summary'] as Map<String, dynamic>?;
    final totalEarnings = (summary?['totalCreatorEarningsInr'] as num?)?.toDouble() ?? 0.0;

    VayuBottomSheet.show(
      context: context,
      title: "Paid Video Sales",
      icon: Icons.monetization_on_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.edgeInsetsAll12,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                AppSpacing.hSpace8,
                Expanded(
                  child: Text(
                    "80% creator share automatically settled on the 1st of every month.",
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vSpace16,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Earnings",
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                "₹${totalEarnings.toStringAsFixed(2)}",
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppSpacing.vSpace16,
          if (sales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No paid video sales yet.",
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sales.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final sale = sales[i];
                  final title = (sale['videoTitle'] ?? 'Paid Video').toString();
                  final price = (sale['priceAmountInr'] as num?)?.toDouble() ?? 0.0;
                  final cut = (sale['creatorEarningsInr'] as num?)?.toDouble() ?? (price * 0.8);
                  final date = sale['unlockedAt'] != null
                      ? sale['unlockedAt'].toString().split('T').first
                      : '';

                  return Container(
                    padding: AppSpacing.edgeInsetsAll12,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderPrimary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                        AppSpacing.hSpace12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (date.isNotEmpty)
                                Text(
                                  date,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AppSpacing.hSpace8,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "+₹${cut.toStringAsFixed(2)}",
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "₹${price.toStringAsFixed(0)}",
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.pop(context),
              label: "Close",
            ),
          ),
          AppSpacing.vSpace8,
        ],
      ),
    );
  }

  void _showMonthlyEarningsSheet() {
    final monthlyEarnings = (_revenueData?['monthlyEarnings'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    if (monthlyEarnings.isEmpty) {
      VayuSnackBar.showInfo(context, 'No monthly earnings data available yet.');
      return;
    }

    // Use the same totalRevenue as displayed on the screen for consistency
    final lifetimeTotal =
        (_revenueData?['totalRevenue'] as num?)?.toDouble() ??
        (_revenueData?['netRevenue'] as num?)?.toDouble() ??
        0.0;

    VayuBottomSheet.show(
      context: context,
      title: "Monthly Earnings",
      icon: Icons.bar_chart_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lifetime total summary at top (consistent with screen)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.spacing3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Lifetime Total", style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  lifetimeTotal.toStringAsFixed(2),
                  style: AppTypography.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          AppSpacing.vSpace16,
          // Monthly list
          ...monthlyEarnings.map((earning) {
            final yearMonth = earning['yearMonth'] ?? '';
            final creatorRevenue = (earning['creatorRevenue'] as num?)?.toDouble() ?? 0.0;

            // Parse year-month to display format
            final parts = yearMonth.split('-');
            final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            String displayMonth = yearMonth;
            if (parts.length == 2) {
              final monthIndex = int.tryParse(parts[1]) ?? 1;
              displayMonth = '${monthNames[monthIndex - 1]} ${parts[0]}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(AppSpacing.spacing3),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayMonth, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text(
                    creatorRevenue.toStringAsFixed(2),
                    style: AppTypography.titleSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
          AppSpacing.vSpace16,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.pop(context),
              label: "Close",
            ),
          ),
          AppSpacing.vSpace8,
        ],
      ),
    );
  }

  Widget _buildRevenueStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 24),
        AppSpacing.vSpace4,
        Text(value, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildRevenueBreakdownCard() {
    final thisMonth = (_revenueData?['thisMonth'] as num?)?.toDouble() ?? 0.0;
    if (thisMonth <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Engagement Breakdown", style: AppTypography.titleMedium),
        AppSpacing.vSpace12,
        Container(
          padding: EdgeInsets.all(AppSpacing.spacing4),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Column(
            children: [
              _buildBreakdownRow("Creator Points", thisMonth.toStringAsFixed(2), AppColors.success),
              const Divider(height: 24),
              _buildBreakdownRow("Platform Support", (thisMonth * 0.25).toStringAsFixed(2), AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(value, style: AppTypography.bodyLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRemovedVideosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            AppSpacing.hSpace8,
            Text("Content Violations", style: AppTypography.titleMedium.copyWith(color: AppColors.error)),
          ],
        ),
        AppSpacing.vSpace12,
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _removedVideos.length,
          separatorBuilder: (_, __) => AppSpacing.vSpace12,
          itemBuilder: (context, index) {
            final video = _removedVideos[index];
            return Container(
              padding: EdgeInsets.all(AppSpacing.spacing3),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  // Non-playable Thumbnail with overlay
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          image: DecorationImage(
                            image: NetworkImage(video.thumbnailUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.6),
                              BlendMode.darken,
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: Center(
                          child: Icon(Icons.block, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.hSpace12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.videoName,
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Reason: ${video.reason}",
                          style: TextStyle(color: AppColors.error.withValues(alpha: 0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreatorAlertsSection() {
    final manager = ref.watch(profileStateManagerProvider);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationPerformanceScreen(manager: manager)),
      ),
      child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.spacing4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFFFD700)),
                  AppSpacing.hSpace8,
                  Text("Send Notification", style: AppTypography.titleMedium),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${manager.remainingAlerts}/2 left today",
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          AppSpacing.vSpace12,
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatorToolsScreen()),
              ),
              label: "Send Notification",
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
          if (manager.creatorAlertStats.isNotEmpty) ...[
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationPerformanceScreen(manager: manager)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Recent Performance", style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}
