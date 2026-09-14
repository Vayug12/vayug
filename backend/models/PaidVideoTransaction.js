import mongoose from 'mongoose';

/**
 * PaidVideoTransaction Model
 *
 * Immutable financial audit ledger for paid video unlocks.
 * Records buyer, creator, revenue share split, and Google Play/RevenueCat reference.
 */
const paidVideoTransactionSchema = new mongoose.Schema({
  buyerId: {
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
  creatorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  priceAmount: {
    type: Number,
    required: true,
    min: 0
  },
  creatorShareAmount: {
    type: Number,
    required: true,
    min: 0
  },
  platformShareAmount: {
    type: Number,
    required: true,
    min: 0
  },
  revenueCatTransactionId: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    index: true
  },
  status: {
    type: String,
    enum: ['completed', 'refunded'],
    default: 'completed',
    index: true
  },
  month: {
    type: String, // Format: YYYY-MM for easy monthly creator payout rollup
    required: true,
    index: true
  }
}, {
  timestamps: true
});

paidVideoTransactionSchema.index({ creatorId: 1, month: 1, createdAt: -1 });

const PaidVideoTransaction = mongoose.model('PaidVideoTransaction', paidVideoTransactionSchema);

export default PaidVideoTransaction;
