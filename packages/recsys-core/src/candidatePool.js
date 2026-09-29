/**
 * In-Memory Candidate Pool.
 * Holds active candidate items in Node.js process memory.
 * Background-syncs from database every N minutes, eliminating expensive DB queries on feed requests.
 */
export class CandidatePool {
  /**
   * @param {Object} options
   * @param {Function} options.loader - Async function that returns Array<Object> from database
   * @param {number} [options.syncIntervalMs=10*60*1000] - Sync interval (default: 10 minutes)
   * @param {number} [options.maxItems=2000] - Max candidate pool capacity
   */
  constructor(options = {}) {
    this.loader = options.loader || null;
    this.syncIntervalMs = options.syncIntervalMs || 10 * 60 * 1000;
    this.maxItems = options.maxItems || 2000;
    
    this.items = [];
    this.lastSyncAt = 0;
    this.timer = null;
    this.isSyncing = false;
  }

  /**
   * Start periodic background sync
   */
  start() {
    if (this.timer) return;
    this.refresh().catch(() => {});
    this.timer = setInterval(() => {
      this.refresh().catch(() => {});
    }, this.syncIntervalMs);
  }

  /**
   * Stop background sync
   */
  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /**
   * Manually trigger pool refresh from DB loader
   */
  async refresh() {
    if (this.isSyncing || typeof this.loader !== 'function') return this.items;
    this.isSyncing = true;
    try {
      const freshItems = await this.loader();
      if (Array.isArray(freshItems) && freshItems.length > 0) {
        this.items = freshItems.slice(0, this.maxItems);
        this.lastSyncAt = Date.now();
      }
    } catch (e) {
      // Keep existing memory items on error
    } finally {
      this.isSyncing = false;
    }
    return this.items;
  }

  /**
   * Query candidate pool with custom in-memory filter predicate
   * @param {Function} [predicate]
   * @returns {Array<Object>}
   */
  getCandidates(predicate) {
    if (!predicate) return [...this.items];
    return this.items.filter(predicate);
  }

  /**
   * Check if candidate pool has fresh data
   */
  isReady() {
    return this.items.length > 0;
  }
}

export default CandidatePool;
