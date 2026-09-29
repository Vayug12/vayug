const TELEGRAM_API_ROOT = 'https://api.telegram.org';
const WEBHOOK_PATH = '/api/telegram/webhook';

class TelegramWebhookService {
  constructor({ fetchImpl = globalThis.fetch } = {}) {
    this.fetchImpl = fetchImpl;
  }

  _config() {
    const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
    const secret = process.env.TELEGRAM_WEBHOOK_SECRET?.trim();
    const explicitUrl = process.env.TELEGRAM_WEBHOOK_URL?.trim();
    const publicBaseUrl = process.env.BACKEND_PUBLIC_URL?.trim()
      || (process.env.FLY_APP_NAME
        ? `https://${process.env.FLY_APP_NAME}.fly.dev`
        : null);
    const url = explicitUrl
      || (publicBaseUrl ? `${publicBaseUrl.replace(/\/$/, '')}${WEBHOOK_PATH}` : null);
    return { token, secret, url };
  }

  async _call(token, method, payload = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    timeout.unref?.();
    try {
      const response = await this.fetchImpl(
        `${TELEGRAM_API_ROOT}/bot${token}/${method}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          signal: controller.signal
        }
      );
      const result = await response.json();
      if (!response.ok || result?.ok !== true) {
        throw new Error(result?.description || `HTTP ${response.status}`);
      }
      return result.result;
    } finally {
      clearTimeout(timeout);
    }
  }

  async configure() {
    const { token, secret, url } = this._config();
    if (!token) {
      console.warn('Telegram webhook disabled: TELEGRAM_BOT_TOKEN is not configured');
      return false;
    }
    if (!secret) {
      console.warn('Telegram webhook disabled: TELEGRAM_WEBHOOK_SECRET is not configured');
      return false;
    }
    if (!/^[A-Za-z0-9_-]{1,256}$/.test(secret)) {
      console.error('Telegram webhook disabled: TELEGRAM_WEBHOOK_SECRET has invalid characters');
      return false;
    }
    if (!url || !url.startsWith('https://')) {
      console.warn('Telegram webhook disabled: no HTTPS public backend URL is configured');
      return false;
    }

    try {
      const current = await this._call(token, 'getWebhookInfo');
      if (current?.last_error_message) {
        console.warn(`Telegram webhook reported a previous delivery error: ${current.last_error_message}`);
      }
      // Register on every boot so a rotated secret is applied even when the URL
      // has not changed. Telegram does not expose the current secret in status.
      await this._call(token, 'setWebhook', {
        url,
        secret_token: secret,
        allowed_updates: ['message'],
        drop_pending_updates: false
      });
      const verified = await this._call(token, 'getWebhookInfo');
      if (verified?.url !== url) {
        throw new Error('Telegram did not retain the configured webhook URL');
      }
      console.log(`Telegram webhook configured (${verified.pending_update_count || 0} pending)`);
      return true;
    } catch (error) {
      console.error('Telegram webhook setup failed:', error.message);
      return false;
    }
  }
}

export { TelegramWebhookService };
export default new TelegramWebhookService();
