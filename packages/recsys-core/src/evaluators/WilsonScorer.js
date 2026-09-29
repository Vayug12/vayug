/**
 * Wilson Score Confidence Interval Scorer.
 * Used by Reddit, YouTube, and Instagram for robust engagement calculation
 * that prevents 1-like-1-view items from dominating items with 1000-likes-1200-views.
 */
export class WilsonScorer {
  /**
   * Calculate Wilson lower bound confidence score
   * @param {number} positive - Positive interactions (likes, shares, comments)
   * @param {number} total - Total opportunities / views
   * @param {number} [confidence=1.96] - 95% confidence standard z-score
   * @returns {number} Score between 0.0 and 1.0
   */
  static score(positive, total, confidence = 1.96) {
    if (!total || total <= 0) return 0;
    const pos = Math.max(0, positive);
    const tot = Math.max(pos, total);

    const p = (pos + 0.5) / (tot + 5); // Laplace smoothed ratio
    const z = confidence;
    const z2 = z * z;

    const numerator = p + z2 / (2 * tot) - z * Math.sqrt((p * (1 - p) + z2 / (4 * tot)) / tot);
    const denominator = 1 + z2 / tot;

    return Math.max(0, Math.min(1, numerator / denominator));
  }
}

export default WilsonScorer;
