/**
 * Diversity Reranker.
 * Prevents fatigue by enforcing a minimum gap (spacing) between items
 * from the same author, creator, channel, or topic category.
 */
export class DiversityReranker {
  /**
   * Reorder items so no attribute (e.g. authorId) appears within minSpacing positions.
   * @param {Array<Object>} items - Ranked items
   * @param {Object} [options]
   * @param {string|Function} [options.key='authorId'] - Attribute name or extractor function
   * @param {number} [options.minSpacing=3] - Minimum slots between consecutive same-key items
   * @returns {Array<Object>} Diversified items list
   */
  static diversify(items, options = {}) {
    if (!items || items.length <= 1) return items || [];

    const keyExtractor = typeof options.key === 'function'
      ? options.key
      : (item) => item[options.key || 'authorId'] || item.uploaderId || item.uploader || 'unknown';

    const minSpacing = options.minSpacing !== undefined ? options.minSpacing : 3;

    const remaining = [...items];
    const result = [];
    const lastPositions = new Map();
    let currentPos = 0;

    while (remaining.length > 0) {
      let candidateIndex = -1;

      for (let i = 0; i < remaining.length; i++) {
        const itemKey = String(keyExtractor(remaining[i]));
        const lastPos = lastPositions.get(itemKey);

        if (lastPos === undefined || (currentPos - lastPos - 1) >= minSpacing) {
          candidateIndex = i;
          break;
        }
      }

      // If no item satisfies spacing constraint, fallback to picking the highest-scored remaining item
      const selectedIndex = candidateIndex !== -1 ? candidateIndex : 0;
      const selectedItem = remaining.splice(selectedIndex, 1)[0];
      
      result.push(selectedItem);
      lastPositions.set(String(keyExtractor(selectedItem)), currentPos);
      currentPos++;
    }

    return result;
  }
}

export default DiversityReranker;
