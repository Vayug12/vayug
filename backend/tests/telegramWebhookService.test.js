import { jest } from '@jest/globals';
import { TelegramWebhookService } from '../services/telegramWebhookService.js';
import telegramService from '../services/telegramService.js';

const ENV_KEYS = [
  'TELEGRAM_BOT_TOKEN',
  'TELEGRAM_WEBHOOK_SECRET',
  'TELEGRAM_WEBHOOK_URL',
  'BACKEND_PUBLIC_URL',
  'FLY_APP_NAME'
];

describe('Telegram webhook setup', () => {
  const originalEnv = {};

  beforeEach(() => {
    for (const key of ENV_KEYS) {
      originalEnv[key] = process.env[key];
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      if (originalEnv[key] === undefined) delete process.env[key];
      else process.env[key] = originalEnv[key];
    }
    jest.restoreAllMocks();
  });

  test('configures and verifies the production webhook', async () => {
    process.env.TELEGRAM_BOT_TOKEN = 'test-token';
    process.env.TELEGRAM_WEBHOOK_SECRET = 'safe_test-secret';
    process.env.FLY_APP_NAME = 'vayug';
    const fetchImpl = jest
      .fn()
      .mockResolvedValueOnce(apiResponse({ url: '' }))
      .mockResolvedValueOnce(apiResponse(true))
      .mockResolvedValueOnce(apiResponse({
        url: 'https://vayug.fly.dev/api/telegram/webhook',
        pending_update_count: 0
      }));

    const configured = await new TelegramWebhookService({ fetchImpl }).configure();

    expect(configured).toBe(true);
    expect(fetchImpl).toHaveBeenCalledTimes(3);
    const setWebhook = JSON.parse(fetchImpl.mock.calls[1][1].body);
    expect(setWebhook).toEqual({
      url: 'https://vayug.fly.dev/api/telegram/webhook',
      secret_token: 'safe_test-secret',
      allowed_updates: ['message'],
      drop_pending_updates: false
    });
  });

  test('does not contact Telegram with incomplete or unsafe config', async () => {
    const fetchImpl = jest.fn();
    const service = new TelegramWebhookService({ fetchImpl });
    expect(await service.configure()).toBe(false);
    process.env.TELEGRAM_BOT_TOKEN = 'test-token';
    process.env.TELEGRAM_WEBHOOK_SECRET = 'spaces are invalid';
    process.env.FLY_APP_NAME = 'vayug';
    expect(await service.configure()).toBe(false);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test('webhook requires the configured Telegram secret header', async () => {
    const previousSecret = telegramService.webhookSecret;
    telegramService.webhookSecret = 'expected-secret';
    try {
      await expect(telegramService.handleWebhookUpdate({}, undefined))
        .resolves.toEqual({ ok: false, error: 'Unauthorized webhook' });
      await expect(telegramService.handleWebhookUpdate({}, 'wrong-secret'))
        .resolves.toEqual({ ok: false, error: 'Unauthorized webhook' });
      await expect(telegramService.handleWebhookUpdate({}, 'expected-secret'))
        .resolves.toEqual({ ok: true });
    } finally {
      telegramService.webhookSecret = previousSecret;
    }
  });
});

function apiResponse(result) {
  return {
    ok: true,
    status: 200,
    json: async () => ({ ok: true, result })
  };
}
