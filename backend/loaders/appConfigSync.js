import AppConfig from '../models/AppConfig.js';
import redisService from '../services/caching/redisService.js';

/**
 * Auto-sync minimum supported version on server startup
 * Ensures that 'fly deploy' alone is sufficient to enforce force updates,
 * without requiring manual SSH or seed scripts.
 */
export default async () => {
  try {
    const targetMinVersion = '3.6.4';
    const targetLatestVersion = '3.6.4';

    // Update active production AppConfig in MongoDB
    const result = await AppConfig.updateMany(
      { environment: 'production' },
      {
        $set: {
          'versionControl.minSupportedAppVersion': targetMinVersion,
          'versionControl.latestAppVersion': targetLatestVersion,
          isActive: true
        }
      }
    );

    // If no document exists yet, create one
    if (result.matchedCount === 0) {
      await AppConfig.create({
        platform: 'android',
        environment: 'production',
        isActive: true,
        versionControl: {
          minSupportedAppVersion: targetMinVersion,
          latestAppVersion: targetLatestVersion,
          forceUpdateMessage: 'Please update Vayug to the latest version to continue.',
          softUpdateMessage: 'A new update is available with better performance!',
          updateUrl: {
            android: 'https://play.google.com/store/apps/details?id=com.snehayog.app',
            ios: 'https://apps.apple.com/app/snehayog'
          }
        }
      });
    }

    // Clear Redis cached config so changes take effect immediately
    if (redisService.getConnectionStatus && redisService.getConnectionStatus()) {
      try {
        await redisService.del('app_config:android:production');
        await redisService.del('app_config:all:production');
      } catch (_) {}
    }

    console.log(`✅ AppConfig: Enforced minSupportedAppVersion=${targetMinVersion} in MongoDB.`);
  } catch (error) {
    console.warn('⚠️ AppConfig: Auto-sync failed (non-critical):', error.message);
  }
};
