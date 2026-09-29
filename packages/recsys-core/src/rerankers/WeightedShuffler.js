/**
 * Weighted Random Shuffler.
 * Uses the Gumbel-Max / exponential key trick: -ln(rand()) / score.
 * Higher scores naturally sort near the top, but with stochastic variance
 * so the user experiences fresh order upon every reload.
 */
export class WeightedShuffler {
  /**
   * Shuffle items weighted by their score attribute
   * @param {Array<Object>} items - Array of scored items
   * @param {number} [count] - Optional slice count
   * @param {string|Function} [scoreKey='score'] - Attribute name or extractor
   * @returns {Array<Object>} Shuffled items
   */
  static shuffle(items, count, scoreKey = 'score') {
    if (!items || items.length <= 1) return items || [];

    const getScore = typeof scoreKey === 'function'
      ? scoreKey
      : (item) => Math.max(0.001, Number(item[scoreKey] || item.finalScore || 0.1));

    const scoredKeys = items.map((item) => {
      const score = getScore(item);
      // Exponential distribution random key: -ln(U) / score
      const u = Math.max(1e-9, Math.random());
      const key = -Math.log(u) / score;
      return { item, key };
    });

    // Sort ascending by key (corresponds to highest score with random variance)
    scoredKeys.sort((a, b) => a.key - b.key);

    const result = scoredKeys.map((k) => k.item);
    return count ? result.slice(0, count) : result;
  }
}

export default WeightedShuffler;
