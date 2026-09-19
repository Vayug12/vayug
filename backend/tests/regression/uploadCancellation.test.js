import request from 'supertest';
import app from '../../server.js';
import mongoose from 'mongoose';
import User from '../../models/User.js';
import Video from '../../models/Video.js';
import { generateJWT } from '../../utils/verifytoken.js';

describe('🛑 Upload Cancellation & Worker Processing Abort', () => {
  let creator;
  let creatorToken;
  let otherUser;
  let otherToken;

  beforeAll(async () => {
    const creatorGoogleId = 'cancel-creator-' + Date.now();
    creator = await User.create({
      googleId: creatorGoogleId,
      name: 'Cancel Test Creator',
      email: 'creator-' + Date.now() + '@example.com',
      videos: []
    });
    creatorToken = generateJWT(creatorGoogleId, '1h');

    const otherGoogleId = 'other-user-' + Date.now();
    otherUser = await User.create({
      googleId: otherGoogleId,
      name: 'Other User',
      email: 'other-' + Date.now() + '@example.com',
      videos: []
    });
    otherToken = generateJWT(otherGoogleId, '1h');
  });

  afterAll(async () => {
    await User.deleteMany({ _id: { $in: [creator._id, otherUser._id] } });
    await Video.deleteMany({ uploader: { $in: [creator._id, otherUser._id] } });
  });

  test('POST /api/upload/video/:videoId/cancel should abort and delete the video document', async () => {
    // 1. Create a video in processing state
    const video = await Video.create({
      uploader: creator._id,
      videoName: 'Video To Cancel',
      videoUrl: 'https://example.com/raw.mp4',
      processingStatus: 'processing',
      processingProgress: 10,
    });

    // 2. Cancel the upload
    const res = await request(app)
      .post(`/api/upload/video/${video._id}/cancel`)
      .set('Authorization', `Bearer ${creatorToken}`)
      .send();

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);

    // 3. Verify video document is deleted from DB
    const found = await Video.findById(video._id);
    expect(found).toBeNull();
  });

  test('POST /api/upload/video/:videoId/cancel should deny access to non-owner', async () => {
    const video = await Video.create({
      uploader: creator._id,
      videoName: 'Protected Video',
      videoUrl: 'https://example.com/raw.mp4',
      processingStatus: 'processing',
    });

    const res = await request(app)
      .post(`/api/upload/video/${video._id}/cancel`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send();

    expect(res.statusCode).toBe(403);
    expect(res.body.success).toBe(false);

    // Verify video is untouched
    const found = await Video.findById(video._id);
    expect(found).not.toBeNull();

    // Clean up
    await Video.findByIdAndDelete(video._id);
  });

  test('POST /api/upload/video/:videoId/cancel should return 200 if video is already gone', async () => {
    const randomId = new mongoose.Types.ObjectId();
    const res = await request(app)
      .post(`/api/upload/video/${randomId}/cancel`)
      .set('Authorization', `Bearer ${creatorToken}`)
      .send();

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
