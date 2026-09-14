import express from 'express';
import mongoose from 'mongoose';
import Video from '../../models/Video.js';
import User from '../../models/User.js';
import PaidVideoUnlock from '../../models/PaidVideoUnlock.js';
import PaidVideoTransaction from '../../models/PaidVideoTransaction.js';
import { verifyToken, passiveVerifyToken } from '../../utils/verifytoken.js';
import redisService from '../../services/caching/redisService.js';

const router = express.Router();

/**
 * Helper to get Redis unlock cache key
 */
const getUnlockCacheKey = (userId, videoId) => `paid_unlock:${String(userId)}:${String(videoId)}`;

/**
 * GET /api/paid-videos/check-access/:videoId
 * Fast check whether the requesting user has unlocked this video.
 * Uses Redis cache-aside to protect MongoDB from read spikes.
 */
router.get('/check-access/:videoId', passiveVerifyToken, async (req, res) => {
  try {
    const { videoId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID', isUnlocked: false });
    }

    // Unauthenticated users cannot have unlocked videos
    if (!req.user?.id && !req.user?.googleId) {
      return res.json({ isUnlocked: false });
    }

    const user = await User.findOne({
      $or: [{ googleId: req.user.googleId || req.user.id }, { _id: mongoose.Types.ObjectId.isValid(req.user.id) ? req.user.id : null }]
    }).select('_id');

    if (!user) {
      return res.json({ isUnlocked: false });
    }

    // 1. Check Redis cache first (Microsecond response)
    const cacheKey = getUnlockCacheKey(user._id, videoId);
    if (redisService.getConnectionStatus()) {
      const cached = await redisService.get(cacheKey);
      if (cached === '1') {
        return res.json({ isUnlocked: true });
      }
    }

    // 2. Check if video exists and if user is the creator (creators always have free access to their own videos)
    const video = await Video.findById(videoId).select('uploader paidAccess');
    if (!video) {
      return res.status(404).json({ error: 'Video not found', isUnlocked: false });
    }

    if (!video.paidAccess?.isPaid) {
      return res.json({ isUnlocked: true });
    }

    if (video.uploader && video.uploader.toString() === user._id.toString()) {
      return res.json({ isUnlocked: true, isOwner: true });
    }

    // 3. Check PaidVideoUnlock collection
    const unlockRecord = await PaidVideoUnlock.exists({ userId: user._id, videoId: video._id });
    const isUnlocked = Boolean(unlockRecord);

    // Cache positive unlock in Redis for 24 hours (86400s)
    if (isUnlocked && redisService.getConnectionStatus()) {
      await redisService.set(cacheKey, '1', 86400);
    }

    return res.json({ isUnlocked });
  } catch (error) {
    console.error('❌ Error checking paid video access:', error);
    return res.status(500).json({ error: 'Internal server error', isUnlocked: false });
  }
});

/**
 * POST /api/paid-videos/unlock
 * Records a verified video unlock after Google Play / RevenueCat purchase.
 * Idempotent: safe against duplicate taps and webhook retries.
 */
router.post('/unlock', verifyToken, async (req, res) => {
  try {
    const { videoId, revenueCatTransactionId, priceTier } = req.body;

    if (!videoId || !revenueCatTransactionId) {
      return res.status(400).json({ error: 'videoId and revenueCatTransactionId are required' });
    }

    const user = await User.findOne({
      $or: [{ googleId: req.user.googleId || req.user.id }, { _id: mongoose.Types.ObjectId.isValid(req.user.id) ? req.user.id : null }]
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const video = await Video.findById(videoId);
    if (!video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    const cleanTxId = String(revenueCatTransactionId).trim();
    const cacheKey = getUnlockCacheKey(user._id, video._id);

    // 1. Idempotency check: Has this transaction already been processed?
    const existingTx = await PaidVideoTransaction.findOne({ revenueCatTransactionId: cleanTxId });
    if (existingTx) {
      if (redisService.getConnectionStatus()) {
        await redisService.set(cacheKey, '1', 86400);
      }
      return res.json({
        success: true,
        message: 'Video already unlocked',
        isUnlocked: true
      });
    }

    // 2. Compute 80/20 revenue share
    const priceAmount = Number(video.paidAccess?.priceAmount) || 0;
    const creatorShare = Math.round(priceAmount * 0.8 * 100) / 100;
    const platformShare = Math.round((priceAmount - creatorShare) * 100) / 100;
    const currentMonth = new Date().toISOString().slice(0, 7); // YYYY-MM

    // 3. Atomically record unlock & transaction
    try {
      await PaidVideoUnlock.updateOne(
        { userId: user._id, videoId: video._id },
        { $setOnInsert: { userId: user._id, videoId: video._id, unlockedAt: new Date() } },
        { upsert: true }
      );

      await PaidVideoTransaction.create({
        buyerId: user._id,
        videoId: video._id,
        creatorId: video.uploader,
        priceAmount,
        creatorShareAmount: creatorShare,
        platformShareAmount: platformShare,
        revenueCatTransactionId: cleanTxId,
        status: 'completed',
        month: currentMonth
      });

      // Update aggregate counters on Video doc
      await Video.updateOne(
        { _id: video._id },
        {
          $inc: {
            'paidAccess.totalPurchases': 1,
            'paidAccess.totalRevenue': priceAmount
          }
        }
      );
    } catch (dbError) {
      // Catch duplicate key error (code 11000) for concurrency safety
      if (dbError.code === 11000) {
        console.log('ℹ️ Handled duplicate unlock race condition gracefully');
      } else {
        throw dbError;
      }
    }

    // 4. Update Redis cache for instant feed playback resume
    if (redisService.getConnectionStatus()) {
      await redisService.set(cacheKey, '1', 86400);
    }

    return res.json({
      success: true,
      message: 'Video unlocked successfully',
      isUnlocked: true
    });
  } catch (error) {
    console.error('❌ Error unlocking paid video:', error);
    return res.status(500).json({ error: 'Failed to unlock video: ' + error.message });
  }
});

/**
 * GET /api/paid-videos/creator-sales
 * Returns total paid video sales and transactions for CreatorRevenueScreen.
 */
router.get('/creator-sales', verifyToken, async (req, res) => {
  try {
    const user = await User.findOne({
      $or: [{ googleId: req.user.googleId || req.user.id }, { _id: mongoose.Types.ObjectId.isValid(req.user.id) ? req.user.id : null }]
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const currentMonth = new Date().toISOString().slice(0, 7);

    // Run parallel aggregation for fast dashboard loading
    const [sales, summaryResult, monthlyResult] = await Promise.all([
      PaidVideoTransaction.find({ creatorId: user._id, status: 'completed' })
        .sort({ createdAt: -1 })
        .limit(50)
        .populate('videoId', 'videoName thumbnailUrl')
        .populate('buyerId', 'name profilePic')
        .lean(),

      PaidVideoTransaction.aggregate([
        { $match: { creatorId: user._id, status: 'completed' } },
        {
          $group: {
            _id: null,
            totalEarnings: { $sum: '$creatorShareAmount' },
            totalPurchases: { $sum: 1 }
          }
        }
      ]),

      PaidVideoTransaction.aggregate([
        { $match: { creatorId: user._id, month: currentMonth, status: 'completed' } },
        {
          $group: {
            _id: null,
            thisMonthEarnings: { $sum: '$creatorShareAmount' },
            thisMonthPurchases: { $sum: 1 }
          }
        }
      ])
    ]);

    const totalEarnings = summaryResult[0]?.totalEarnings || 0;
    const totalPurchases = summaryResult[0]?.totalPurchases || 0;
    const thisMonthEarnings = monthlyResult[0]?.thisMonthEarnings || 0;
    const thisMonthPurchases = monthlyResult[0]?.thisMonthPurchases || 0;

    return res.json({
      summary: {
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        totalPurchases,
        thisMonthEarnings: Math.round(thisMonthEarnings * 100) / 100,
        thisMonthPurchases,
        upiId: user.paymentDetails?.upiId || user.preferredPaymentMethod === 'upi' ? user.paymentDetails?.upiId : null
      },
      sales: sales.map(s => ({
        id: s._id,
        videoId: s.videoId?._id,
        videoName: s.videoId?.videoName || 'Paid Video',
        thumbnailUrl: s.videoId?.thumbnailUrl || '',
        buyerName: s.buyerId?.name || 'Vayu Viewer',
        buyerProfilePic: s.buyerId?.profilePic || '',
        priceAmount: s.priceAmount,
        creatorShareAmount: s.creatorShareAmount,
        createdAt: s.createdAt
      }))
    });
  } catch (error) {
    console.error('❌ Error fetching creator paid video sales:', error);
    return res.status(500).json({ error: 'Failed to fetch sales: ' + error.message });
  }
});

export default router;
