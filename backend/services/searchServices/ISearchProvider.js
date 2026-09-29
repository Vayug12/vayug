/**
 * Abstract class defining the contract for search providers (FFmpeg Search Codecs).
 * 
 * Any search provider (Mongo, Elasticsearch, mock, etc.) must extend this class
 * and implement these methods.
 */
export class ISearchProvider {
  /**
   * Search for videos.
   * @param {string} query The search query string
   * @param {number} limit Maximum results to return
   * @returns {Promise<Array<Object>>} Normalized list of video objects
   */
  async searchVideos(query, limit) {
    throw new Error('searchVideos() not implemented');
  }

  /**
   * Search for creators/users.
   * @param {string} query The search query string
   * @param {number} limit Maximum results to return
   * @returns {Promise<Array<Object>>} Normalized list of creator/user objects
   */
  async searchCreators(query, limit) {
    throw new Error('searchCreators() not implemented');
  }

  /**
   * Unified search returning creators, creator's own uploads, and relevant content.
   * @param {string} query The search query string
   * @param {number} limit Maximum results to return
   * @returns {Promise<{creators: Array<Object>, creatorVideos: Array<Object>, videos: Array<Object>}>}
   */
  async searchUnified(query, limit) {
    throw new Error('searchUnified() not implemented');
  }
}
