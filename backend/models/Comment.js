import mongoose from 'mongoose';

const commentSchema = new mongoose.Schema(
  {
    content: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    targetType: {
      type: String,
      enum: ['video', 'ad'],
      default: 'video',
      index: true
    },
    targetId: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: 'targetTypeRef',
      required: true,
      index: true
    },
    likes: {
      type: Number,
      default: 0,
      min: 0
    },
    likedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
      }
    ]
  },
  {
    timestamps: true
  }
);

commentSchema.virtual('targetTypeRef').get(function () {
  return this.targetType === 'ad' ? 'AdCreative' : 'Video';
});

// Compound indexes for optimal retrieval & sorting
commentSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });
commentSchema.index({ user: 1, createdAt: -1 });

export default mongoose.model('Comment', commentSchema);
