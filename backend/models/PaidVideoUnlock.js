import mongoose from 'mongoose';

/**
 * PaidVideoUnlock Model
 *
 * Designed for high-throughput concurrency (1,000+ concurrent unlocks).
 * Keeps individual user unlocks out of the Video document to prevent
 * document write locks and the 16MB document size limit.
 */
const paidVideoUnlockSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  videoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Video',
    required: true,
    index: true
  },
  unlockedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Compound unique index guarantees 0 duplicate unlocks and O(1) query time
paidVideoUnlockSchema.index({ userId: 1, videoId: 1 }, { unique: true });

const PaidVideoUnlock = mongoose.model('PaidVideoUnlock', paidVideoUnlockSchema);

export default PaidVideoUnlock;
