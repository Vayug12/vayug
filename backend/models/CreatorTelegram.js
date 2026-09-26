import mongoose from 'mongoose';

const creatorTelegramSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true
    },
    chatId: {
      type: String,
      default: null,
      index: true,
      sparse: true
    },
    username: {
      type: String,
      default: null,
      trim: true
    },
    isConnected: {
      type: Boolean,
      default: false,
      index: true
    },
    notifyOnComments: {
      type: Boolean,
      default: true
    },
    linkToken: {
      type: String,
      default: null,
      index: true,
      sparse: true
    },
    linkTokenExpires: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true
  }
);

// Compound index for link token resolution
creatorTelegramSchema.index({ linkToken: 1, linkTokenExpires: 1 });

export default mongoose.model('CreatorTelegram', creatorTelegramSchema);
