import express from 'express';
import telegramService from '../services/telegramService.js';
import verifyToken from '../utils/verifytoken.js';

const router = express.Router();

/**
 * Public Webhook for Telegram updates
 * URL: POST /api/telegram/webhook
 */
router.post('/webhook', async (req, res) => {
  try {
    const secretHeader = req.headers['x-telegram-bot-api-secret-token'];
    const result = await telegramService.handleWebhookUpdate(req.body, secretHeader);
    return res.status(200).json(result);
  } catch (err) {
    console.error('❌ Webhook error:', err.message);
    return res.status(200).json({ ok: true }); // Always return 200 to Telegram so it doesn't retry spam
  }
});

/**
 * Protected routes (Creator Auth)
 */
router.use(verifyToken);

/**
 * Generate deep link token
 * POST /api/telegram/link-token
 */
router.post('/link-token', async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'User ID missing' });
    }

    const data = await telegramService.generateLinkToken(userId);
    return res.status(200).json({ ok: true, ...data });
  } catch (err) {
    console.error('❌ Link token error:', err.message);
    return res.status(500).json({ error: 'Failed to generate link token' });
  }
});

/**
 * Get Telegram status
 * GET /api/telegram/status
 */
router.get('/status', async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'User ID missing' });
    }

    const status = await telegramService.getStatus(userId);
    return res.status(200).json({ ok: true, ...status });
  } catch (err) {
    console.error('❌ Get status error:', err.message);
    return res.status(500).json({ error: 'Failed to get status' });
  }
});

/**
 * Disconnect Telegram
 * DELETE /api/telegram/disconnect
 */
router.delete('/disconnect', async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'User ID missing' });
    }

    const result = await telegramService.disconnect(userId);
    return res.status(200).json(result);
  } catch (err) {
    console.error('❌ Disconnect error:', err.message);
    return res.status(500).json({ error: 'Failed to disconnect Telegram' });
  }
});

export default router;
