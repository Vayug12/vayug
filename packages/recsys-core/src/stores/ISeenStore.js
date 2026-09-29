/**
 * Interface contract for Seen Stores.
 * Any custom seen store (Postgres, Mongo, DynamoDB, etc.) must implement these methods.
 */
export class ISeenStore {
  /**
   * Mark items as seen for a specific user or device.
   * @param {string} userKey - User identifier (Google ID, UUID, deviceId)
   * @param {Array<string>} itemIds - Array of item IDs to mark as seen
   * @param {number} ttlSeconds - Expiration time in seconds (default: 30 days)
   * @returns {Promise<boolean>}
   */
  async markSeen(userKey, itemIds, ttlSeconds = 30 * 24 * 60 * 60) {
    throw new Error('markSeen() must be implemented by subclass');
  }

  /**
   * Check which items have already been seen by the user.
   * @param {string} userKey - User identifier
   * @param {Array<string>} itemIds - Array of item IDs to check
   * @returns {Promise<Array<boolean>>} Array of booleans corresponding to itemIds
   */
  async hasSeen(userKey, itemIds) {
    throw new Error('hasSeen() must be implemented by subclass');
  }

  /**
   * Clear seen history for a user.
   * @param {string} userKey - User identifier
   * @returns {Promise<boolean>}
   */
  async clear(userKey) {
    throw new Error('clear() must be implemented by subclass');
  }
}

export default ISeenStore;
