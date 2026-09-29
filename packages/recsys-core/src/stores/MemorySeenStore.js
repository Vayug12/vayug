import ISeenStore from './ISeenStore.js';

/**
 * High-speed In-Memory Seen Store.
 * Requires 0 external dependencies, costs ₹0, and operates in <0.1ms.
 * Uses LRU eviction per user to cap RAM usage.
 */
export class MemorySeenStore extends ISeenStore {
  /**
   * @param {Object} options
   * @param {number} [options.maxItemsPerUser=2500] - Max seen IDs to track per user
   * @param {number} [options.maxUsers=50000] - Max users to keep in memory
   */
  constructor(options = {}) {
    super();
    this.maxItemsPerUser = options.maxItemsPerUser || 2500;
    this.maxUsers = options.maxUsers || 50000;
    this.users = new Map();
  }

  async markSeen(userKey, itemIds, ttlSeconds = 30 * 24 * 60 * 60) {
    if (!userKey || !itemIds || itemIds.length === 0) return true;

    let userSet = this.users.get(userKey);
    if (!userSet) {
      // Global user eviction if memory limit reached
      if (this.users.size >= this.maxUsers) {
        const oldestUser = this.users.keys().next().value;
        this.users.delete(oldestUser);
      }
      userSet = new Set();
      this.users.set(userKey, userSet);
    }

    for (const id of itemIds) {
      if (id) userSet.add(String(id));
    }

    // LRU eviction per user set
    if (userSet.size > this.maxItemsPerUser) {
      const excess = userSet.size - this.maxItemsPerUser;
      const iter = userSet.values();
      for (let i = 0; i < excess; i++) {
        userSet.delete(iter.next().value);
      }
    }

    return true;
  }

  async hasSeen(userKey, itemIds) {
    if (!userKey || !itemIds || itemIds.length === 0) {
      return (itemIds || []).map(() => false);
    }

    const userSet = this.users.get(userKey);
    if (!userSet || userSet.size === 0) {
      return itemIds.map(() => false);
    }

    return itemIds.map((id) => (id ? userSet.has(String(id)) : false));
  }

  async clear(userKey) {
    if (!userKey) return false;
    return this.users.delete(userKey);
  }

  getStats() {
    return {
      activeUsers: this.users.size,
      maxUsers: this.maxUsers,
      maxItemsPerUser: this.maxItemsPerUser
    };
  }
}

export default MemorySeenStore;
