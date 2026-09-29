import { ISearchProvider } from './ISearchProvider.js';
import Video from '../../models/Video.js';
import User from '../../models/User.js';

/**
 * MongoDB Implementation of ISearchProvider (MongoDB Atlas + Regex Fallbacks).
 */
export default class MongoSearchProvider extends ISearchProvider {
  /**
   * Search for videos using Atlas Compound Search or Regex Fallback.
   * @param {string} query
   * @param {number} limit
   * @returns {Promise<Array>} Normalized videos
   */
  /**
   * Search for videos prioritizing creator-owned uploads if a creator name matches,
   * followed by content-matching videos from other creators.
   * @param {string} query
   * @param {number} limit
   * @returns {Promise<Array>} Normalized videos
   */
  async searchVideos(query, limit) {
    const q = query.trim();
    if (!q) return [];

    const unified = await this.searchUnified(q, limit);
    return [...unified.creatorVideos, ...unified.videos].slice(0, limit);
  }

  /**
   * Unified search returning creators, creator's own uploads, and relevant content.
   * Eliminates random un-related video matches.
   * @param {string} query
   * @param {number} limit
   * @returns {Promise<{creators: Array, creatorVideos: Array, videos: Array}>}
   */
  async searchUnified(query, limit) {
    const q = query.trim();
    if (!q) return { creators: [], creatorVideos: [], videos: [] };

    console.log(`🔍 MongoSearchProvider: Executing unified search for "${q}"`);

    try {
      // 1. Search for matching creators/channels
      const creators = await this.searchCreators(q, 5);

      // 2. If creators match, fetch videos uploaded by these specific creators
      let creatorVideos = [];
      const creatorIds = creators
        .map(c => c._id)
        .filter(id => id != null);

      if (creatorIds.length > 0) {
        console.log(`🎯 MongoSearchProvider: Found ${creatorIds.length} matched creator(s). Fetching their uploads...`);
        const rawCreatorVideos = await Video.find({
          uploader: { $in: creatorIds },
          processingStatus: 'completed'
        })
        .limit(limit)
        .populate('uploader', 'googleId name profilePic')
        .sort({ uploadedAt: -1 })
        .lean();

        creatorVideos = rawCreatorVideos.map(v => ({
          ...v,
          id: v._id.toString()
        }));
      }

      // 3. Search for other relevant videos matching title/description/tags
      // Exclude videos already included in creatorVideos
      const existingVideoIds = creatorVideos.map(v => v._id);

      const regexEscaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const searchRegex = new RegExp(regexEscaped, 'i');

      const rawOtherVideos = await Video.find({
        _id: { $nin: existingVideoIds },
        processingStatus: 'completed',
        $or: [
          { videoName: searchRegex },
          { description: searchRegex },
          { tags: searchRegex },
          { category: searchRegex }
        ]
      })
      .limit(limit)
      .populate('uploader', 'googleId name profilePic')
      .sort({ views: -1, uploadedAt: -1 })
      .lean();

      const otherVideos = rawOtherVideos.map(v => ({
        ...v,
        id: v._id.toString()
      }));

      return {
        creators,
        creatorVideos,
        videos: otherVideos
      };

    } catch (err) {
      console.error('❌ MongoSearchProvider unified search error:', err);
      return { creators: [], creatorVideos: [], videos: [] };
    }
  }

  /**
   * Search for creators using Atlas Search or Regex Fallback.
   * @param {string} query
   * @param {number} limit
   * @returns {Promise<Array>} Normalized creators
   */
  async searchCreators(query, limit) {
    const q = query.trim();
    if (!q) return [];

    console.log(`🔍 MongoSearchProvider: Querying creators for "${q}"`);

    try {
      let creators = await User.aggregate([
        {
          $search: {
            index: 'default',
            compound: {
              should: [
                {
                  text: {
                    query: q,
                    path: 'name',
                    score: { boost: { value: 3 } }
                  }
                },
                {
                  text: {
                    query: q,
                    path: 'name',
                    fuzzy: { maxEdits: 1 }
                  }
                }
              ]
            }
          }
        },
        { $limit: limit },
        {
          $project: {
            score: { $meta: 'searchScore' },
            _id: 1,
            googleId: 1,
            name: 1,
            profilePic: 1,
            bio: 1,
            followerCount: 1,
            followingCount: 1,
            createdAt: 1
          }
        }
      ]);

      console.log(`📡 MongoSearchProvider Atlas Search (creators): Found ${creators.length} results`);

      // Fallback if Atlas returns nothing
      if (creators.length === 0) {
        console.log('MongoSearchProvider Atlas Search returned 0 creators, attempting regex fallback...');
        creators = await User.find({
          name: { $regex: q, $options: 'i' }
        })
        .limit(limit)
        .lean();
      }

      return creators.map(u => ({
        ...u,
        id: u.googleId || (u._id ? u._id.toString() : ''),
        _id: u._id,
        followersCount: u.followerCount || 0,
        followingCount: u.followingCount || 0,
      }));

    } catch (err) {
      console.error('❌ MongoSearchProvider Search Error (creators):', err);

      try {
        const fallback = await User.find({
          name: { $regex: q, $options: 'i' }
        })
        .limit(limit)
        .lean();

        return fallback.map(u => ({
          ...u,
          id: u.googleId || (u._id ? u._id.toString() : ''),
          followersCount: u.followerCount || 0,
          followingCount: u.followingCount || 0
        }));
      } catch (fallbackErr) {
        console.error('❌ MongoSearchProvider Total Search Failure (creators):', fallbackErr);
        return [];
      }
    }
  }
}
