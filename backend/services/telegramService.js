import crypto from 'crypto';
import CreatorTelegram from '../models/CreatorTelegram.js';
import redisService from './caching/redisService.js';

class TelegramService {
  constructor() {
    this.botToken = process.env.TELEGRAM_BOT_TOKEN;
    this.botUsername = process.env.TELEGRAM_BOT_USERNAME || 'vayug_bot';
    this.webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET;
    this.localCache = new Map(); // Quick in-process cache (5-min TTL)
  }

  _getCacheKey(userId) {
    return `tg:creator:${userId}`;
  }

  _getToken() {
    return process.env.TELEGRAM_BOT_TOKEN || this.botToken;
  }

  _getUsername() {
    return process.env.TELEGRAM_BOT_USERNAME || this.botUsername || 'vayug_bot';
  }

  /**
   * Send HTTP POST to Telegram Bot API
   */
  async _callTelegramApi(method, payload) {
    const token = this._getToken();
    if (!token) {
      console.error(`Telegram API [${method}] skipped: bot token is not configured`);
      return { ok: false, description: 'Bot token is not configured' };
    }

    try {
      const response = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const result = await response.json();
      if (!response.ok || result?.ok !== true) {
        console.error(`Telegram API [${method}] rejected:`, result?.description || `HTTP ${response.status}`);
      }
      return result;
    } catch (err) {
      console.error(`❌ Telegram API [${method}] Error:`, err.message);
      return null;
    }
  }

  /**
   * Generate temporary link token for creator deep link
   */
  async generateLinkToken(userId) {
    const token = `tg_${crypto.randomBytes(6).toString('hex')}`;
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await CreatorTelegram.findOneAndUpdate(
      { user: userId },
      {
        $set: {
          linkToken: token,
          linkTokenExpires: expires
        }
      },
      { upsert: true, new: true }
    );

    const botUser = this._getUsername();
    return {
      linkToken: token,
      botUsername: botUser,
      linkUrl: `https://t.me/${botUser}?start=${token}`
    };
  }

  /**
   * Get Telegram connection status for creator (Cached)
   */
  async getStatus(userId) {
    const userIdStr = userId.toString();
    const cached = this.localCache.get(userIdStr);
    if (cached && Date.now() - cached.time < 300000) {
      return cached.data;
    }

    const doc = await CreatorTelegram.findOne({ user: userId }).lean();
    const data = {
      isConnected: Boolean(doc?.isConnected),
      username: doc?.username || null,
      notifyOnComments: doc?.notifyOnComments ?? true
    };

    this.localCache.set(userIdStr, { data, time: Date.now() });
    return data;
  }

  /**
   * Process incoming Telegram webhook updates
   */
  async handleWebhookUpdate(update, secretTokenHeader) {
    const expectedSecret = this.webhookSecret || process.env.TELEGRAM_WEBHOOK_SECRET;
    if (!expectedSecret || !this._matchesSecret(secretTokenHeader, expectedSecret)) {
      return { ok: false, error: 'Unauthorized webhook' };
    }

    const message = update?.message;
    if (!message || !message.text) {
      return { ok: true };
    }

    const text = message.text.trim();
    const chatId = message.chat?.id?.toString();
    const tgUsername = message.from?.username ? `@${message.from.username}` : message.from?.first_name || 'Creator';

    if (text.startsWith('/start')) {
      const parts = text.split(' ');
      const token = parts[1]?.trim();

      if (!token) {
        await this._callTelegramApi('sendMessage', {
          chat_id: chatId,
          text: '👋 Welcome to Vayu Bot!\n\nPlease connect your account from inside the Vayu App to receive notifications.'
        });
        return { ok: true };
      }

      // Find by valid linkToken
      const creatorDoc = await CreatorTelegram.findOne({
        linkToken: token,
        linkTokenExpires: { $gt: new Date() }
      });

      if (!creatorDoc) {
        await this._callTelegramApi('sendMessage', {
          chat_id: chatId,
          text: '⚠️ This link token is expired or invalid. Please generate a new connection link in the Vayu App.'
        });
        return { ok: true };
      }

      const confirmation = await this._callTelegramApi('sendMessage', {
        chat_id: chatId,
        parse_mode: 'HTML',
        text: `🎉 <b>Connected Successfully!</b>\n\nYour Vayu creator account is now linked. You will receive instant notifications whenever someone comments on your videos.`
      });
      if (confirmation?.ok !== true) {
        throw new Error(confirmation?.description || 'Telegram rejected the connection confirmation');
      }

      creatorDoc.chatId = chatId;
      creatorDoc.username = tgUsername;
      creatorDoc.isConnected = true;
      creatorDoc.linkToken = null;
      creatorDoc.linkTokenExpires = null;
      await creatorDoc.save();

      // Invalidate memory cache
      this.localCache.delete(creatorDoc.user.toString());
    }

    return { ok: true };
  }

  _matchesSecret(provided, expected) {
    if (!provided || !expected) return false;
    const providedBuffer = Buffer.from(String(provided));
    const expectedBuffer = Buffer.from(String(expected));
    return providedBuffer.length === expectedBuffer.length
      && crypto.timingSafeEqual(providedBuffer, expectedBuffer);
  }

  /**
   * Async dispatch comment notification to creator's Telegram
   */
  async notifyVideoComment({ uploaderId, commenterUser, videoTitle, videoId, commentContent }) {
    if (!uploaderId) return;

    try {
      const status = await this.getStatus(uploaderId);
      if (!status.isConnected || !status.notifyOnComments) return;

      const doc = await CreatorTelegram.findOne({ user: uploaderId, isConnected: true }).select('chatId').lean();
      if (!doc || !doc.chatId) return;

      const commenterName = commenterUser?.name || 'A user';
      const cleanTitle = (videoTitle || 'your video').replace(/[<>&]/g, '');
      const cleanComment = (commentContent || '').replace(/[<>&]/g, '');

      const messageHtml = [
        `💬 <b>New Comment on your video!</b>\n`,
        `📹 <b>Video:</b> ${cleanTitle}`,
        `👤 <b>User:</b> ${commenterName}`,
        `📝 <b>Comment:</b>`,
        `<blockquote>${cleanComment}</blockquote>\n`,
        `<a href="https://snehayog.site/video/${videoId}">🔗 Open in Vayu</a>`
      ].join('\n');

      const result = await this._callTelegramApi('sendMessage', {
        chat_id: doc.chatId,
        parse_mode: 'HTML',
        text: messageHtml,
        disable_web_page_preview: true
      });
      if (result?.ok !== true) {
        throw new Error(result?.description || 'Telegram rejected the notification');
      }
    } catch (err) {
      console.error('⚠️ Failed to dispatch Telegram notification:', err.message);
    }
  }

  /**
   * Disconnect Telegram
   */
  async disconnect(userId) {
    await CreatorTelegram.findOneAndUpdate(
      { user: userId },
      {
        $set: {
          isConnected: false,
          chatId: null,
          username: null,
          linkToken: null
        }
      }
    );
    this.localCache.delete(userId.toString());
    return { ok: true };
  }
}

export default new TelegramService();
