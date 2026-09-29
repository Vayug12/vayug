/**
 * Time Decay & Fatigue Formulas.
 * Implements smooth gravity-style decay to give fresh content an opportunity
 * while allowing truly viral content to remain discoverable.
 */
export class DecayFormula {
  /**
   * Gravity / Half-life decay for item age.
   * @param {Date|number|string} createdAt - Publication timestamp
   * @param {Object} [options]
   * @param {number} [options.halfLifeHours=48] - Hours until score halves
   * @param {number} [options.freshnessBoostWindowHours=72] - Window for initial boost
   * @param {number} [options.freshnessMultiplier=1.5] - Multiplier during fresh window
   * @returns {number} Decay multiplier between 0.05 and 2.5
   */
  static recencyDecay(createdAt, options = {}) {
    const halfLifeHours = options.halfLifeHours || 48;
    const boostWindow = options.freshnessBoostWindowHours || 72;
    const boostMult = options.freshnessMultiplier || 1.5;

    const createdTime = new Date(createdAt).getTime();
    if (isNaN(createdTime)) return 1.0;

    const ageInHours = Math.max(0, (Date.now() - createdTime) / (1000 * 60 * 60));
    
    // Half-life exponential decay: 2^(-age / halfLife)
    const baseDecay = Math.pow(0.5, ageInHours / halfLifeHours);

    // Freshness boost for newly uploaded content
    let boost = 0;
    if (ageInHours < boostWindow) {
      boost = (1 - ageInHours / boostWindow) * (boostMult - 1.0);
    }

    return Math.max(0.05, baseDecay + boost);
  }

  /**
   * Calculate penalty for quick skips / low retention
   * @param {number} skips - Count of items swiped in <2s
   * @param {number} totalViews - Total view count
   * @param {number} [penaltyMultiplier=1.5]
   * @returns {number} Penalty value >= 0
   */
  static skipPenalty(skips, totalViews, penaltyMultiplier = 1.5) {
    if (!totalViews || totalViews <= 0) return 0;
    const skipRatio = Math.max(0, skips) / totalViews;
    return Math.min(1.0, skipRatio * penaltyMultiplier);
  }
}

export default DecayFormula;
