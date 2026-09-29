import MemorySeenStore from './stores/MemorySeenStore.js';
import DiversityReranker from './rerankers/DiversityReranker.js';
import WeightedShuffler from './rerankers/WeightedShuffler.js';

/**
 * Universal Feed Orchestrator.
 * Connects candidate retrieval, seen-state de-duplication, custom evaluators,
 * diversity spacing, and weighted shuffling into a zero-cost, plug-and-play pipeline.
 */
export class FeedOrchestrator {
  /**
   * @param {Object} options
   * @param {ISeenStore} [options.seenStore] - Store instance for tracking viewed items
   * @param {Array<Function>} [options.evaluators] - Array of async (item, context) => score functions
   * @param {Object} [options.diversity] - Diversity options { key, minSpacing }
   * @param {boolean} [options.enableShuffle=true] - Enable stochastic weighted shuffle
   * @param {number} [options.seenTtlSeconds=30*24*60*60] - Seen duration (30 days default)
   */
  constructor(options = {}) {
    this.seenStore = options.seenStore || new MemorySeenStore();
    this.evaluators = options.evaluators || [];
    this.diversityOptions = options.diversity || { minSpacing: 3 };
    this.enableShuffle = options.enableShuffle !== false;
    this.seenTtlSeconds = options.seenTtlSeconds || 30 * 24 * 60 * 60;
  }

  /**
   * Register a custom scoring/evaluation function: async (item, context) => number
   * @param {Function} evaluatorFn
   */
  addEvaluator(evaluatorFn) {
    if (typeof evaluatorFn === 'function') {
      this.evaluators.push(evaluatorFn);
    }
    return this;
  }

  /**
   * Generate a ranked, de-duplicated feed for a user
   * @param {Object} params
   * @param {string} params.userKey - Unique identifier (userId or deviceId)
   * @param {Array<Object>} params.candidates - Initial pool of candidate items
   * @param {Array<string>} [params.excludeIds] - Temporary client-side on-screen IDs to exclude
   * @param {Object} [params.context={}] - User preferences, location, interest vectors
   * @param {number} [params.limit=10] - Number of items to return
   * @param {boolean} [params.markAsSeen=true] - Whether to automatically mark served items as seen
   * @returns {Promise<Array<Object>>}
   */
  async getFeed({
    userKey,
    candidates = [],
    excludeIds = [],
    context = {},
    limit = 10,
    markAsSeen = true
  }) {
    if (!candidates || candidates.length === 0) return [];

    const effectiveUserKey = userKey && userKey !== 'anon' && userKey !== 'undefined'
      ? String(userKey)
      : null;

    const excludeSet = new Set((excludeIds || []).map(String));

    // STAGE 1: Fast in-memory exclusions (client exclude list)
    let filtered = candidates.filter((item) => {
      const id = String(item.id || item._id);
      return !excludeSet.has(id);
    });

    // STAGE 2: Hard Seen De-duplication (30-day SeenStore check)
    if (effectiveUserKey && filtered.length > 0) {
      const idsToCheck = filtered.map((item) => String(item.id || item._id));
      const seenFlags = await this.seenStore.hasSeen(effectiveUserKey, idsToCheck);

      const unreadItems = filtered.filter((_, idx) => !seenFlags[idx]);

      // If user has unread items, prioritize them!
      // If user has read all candidates (catalogue exhaustion), fallback to oldest items
      if (unreadItems.length > 0) {
        filtered = unreadItems;
      }
    }

    if (filtered.length === 0) return [];

    // STAGE 3: Multi-Objective Custom Evaluation & Scoring
    const scoredItems = await Promise.all(
      filtered.map(async (item) => {
        let totalScore = Number(item.baseScore || item.finalScore || 1.0);

        for (const evaluator of this.evaluators) {
          try {
            const delta = await evaluator(item, context);
            if (typeof delta === 'number' && !isNaN(delta)) {
              totalScore += delta;
            }
          } catch (e) {
            // Ignore evaluator error and keep base score
          }
        }

        return {
          ...item,
          score: Math.max(0.01, totalScore)
        };
      })
    );

    // Sort descending by score
    scoredItems.sort((a, b) => b.score - a.score);

    // STAGE 4: Diversity & Anti-Fatigue Spacing
    const diversified = DiversityReranker.diversify(scoredItems, this.diversityOptions);

    // STAGE 5: Weighted Shuffle (Prevents static/stale feed order)
    const finalItems = this.enableShuffle
      ? WeightedShuffler.shuffle(diversified, limit, (i) => i.score)
      : diversified.slice(0, limit);

    // STAGE 6: Mark served items as seen
    if (markAsSeen && effectiveUserKey && finalItems.length > 0) {
      const servedIds = finalItems.map((item) => String(item.id || item._id)).filter(Boolean);
      await this.seenStore.markSeen(effectiveUserKey, servedIds, this.seenTtlSeconds);
    }

    return finalItems;
  }
}

export default FeedOrchestrator;
