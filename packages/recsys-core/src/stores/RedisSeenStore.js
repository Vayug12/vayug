import ISeenStore from './ISeenStore.js';
import MemorySeenStore from './MemorySeenStore.js';

/**
 * Distributed Redis Seen Store with automatic local in-memory fallback.
 * Compatible with Upstash REST SDK, ioredis, or node-redis.
 */
export class RedisSeenStore extends ISeenStore {
  /**
   * @param {Object} options
   * @param {Object} options.redisClient - Redis client (supports sadd, smismember, expire)
   * @param {string} [options.keyPrefix='recsys:seen:'] - Redis key prefix
   * @param {MemorySeenStore} [options.memoryFallback] - Optional in-memory fallback store
   */
  constructor(options = {}) {
    super();
    this.client = options.redisClient || null;
    this.keyPrefix = options.keyPrefix || 'recsys:seen:';
    this.fallback = options.memoryFallback || new MemorySeenStore();
  }

  _getKey(userKey) {
    return `${this.keyPrefix}${userKey}`;
  }

  async markSeen(userKey, itemIds, ttlSeconds = 30 * 24 * 60 * 60) {
    if (!userKey || !itemIds || itemIds.length === 0) return true;

    // Always keep in local memory fallback
    await this.fallback.markSeen(userKey, itemIds, ttlSeconds);

    if (!this.client) return true;

    try {
      const key = this._getKey(userKey);
      const strIds = itemIds.map(String).filter(Boolean);
      if (strIds.length > 0) {
        if (typeof this.client.sadd === 'function') {
          await this.client.sadd(key, ...strIds);
        }
        if (typeof this.client.expire === 'function') {
          await this.client.expire(key, ttlSeconds);
        }
      }
      return true;
    } catch (e) {
      // Graceful fallback to memory on Redis rate limit or disconnect
      return true;
    }
  }

  async hasSeen(userKey, itemIds) {
    if (!userKey || !itemIds || itemIds.length === 0) {
      return (itemIds || []).map(() => false);
    }

    // Check fast memory first
    const memResults = await this.fallback.hasSeen(userKey, itemIds);
    const needRedis = [];
    const needIndices = [];

    memResults.forEach((seen, idx) => {
      if (!seen) {
        needRedis.push(String(itemIds[idx]));
        needIndices.push(idx);
      }
    });

    if (needRedis.length === 0 || !this.client) {
      return memResults;
    }

    try {
      const key = this._getKey(userKey);
      if (typeof this.client.smismember === 'function') {
        const redisFlags = await this.client.smismember(key, ...needRedis);
        redisFlags.forEach((flag, i) => {
          if (flag === 1 || flag === true) {
            const originalIdx = needIndices[i];
            memResults[originalIdx] = true;
          }
        });
      }
    } catch (e) {
      // Return memory results on network/redis error
    }

    return memResults;
  }

  async clear(userKey) {
    await this.fallback.clear(userKey);
    if (!this.client || !userKey) return true;
    try {
      const key = this._getKey(userKey);
      if (typeof this.client.del === 'function') {
        await this.client.del(key);
      }
      return true;
    } catch (e) {
      return true;
    }
  }
}

export default RedisSeenStore;
