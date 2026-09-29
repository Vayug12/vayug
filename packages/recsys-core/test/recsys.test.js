import test from 'node:test';
import assert from 'node:assert';
import {
  FeedOrchestrator,
  MemorySeenStore,
  WilsonScorer,
  DecayFormula,
  DiversityReranker,
  WeightedShuffler
} from '../index.js';

test('MemorySeenStore: tracks and filters seen items correctly', async () => {
  const store = new MemorySeenStore();
  const user = 'user_123';
  const items = ['video_1', 'video_2', 'video_3'];

  // Initially none are seen
  let flags = await store.hasSeen(user, items);
  assert.deepStrictEqual(flags, [false, false, false]);

  // Mark video_1 and video_3 as seen
  await store.markSeen(user, ['video_1', 'video_3']);

  flags = await store.hasSeen(user, items);
  assert.deepStrictEqual(flags, [true, false, true]);

  // Clear seen history
  await store.clear(user);
  flags = await store.hasSeen(user, items);
  assert.deepStrictEqual(flags, [false, false, false]);
});

test('WilsonScorer: gives robust positive interval score', () => {
  const scoreHighRatio = WilsonScorer.score(100, 100);
  const scoreLowRatio = WilsonScorer.score(1, 100);
  assert(scoreHighRatio > scoreLowRatio, 'High engagement should score higher');
  assert(scoreHighRatio <= 1.0 && scoreHighRatio >= 0.0);
});

test('DiversityReranker: enforces spacing between same author', () => {
  const items = [
    { id: '1', authorId: 'creator_A' },
    { id: '2', authorId: 'creator_A' },
    { id: '3', authorId: 'creator_B' },
    { id: '4', authorId: 'creator_C' },
    { id: '5', authorId: 'creator_A' }
  ];

  const diversified = DiversityReranker.diversify(items, { minSpacing: 2 });
  const ids = diversified.map(i => i.id);

  // creator_A shouldn't be consecutive
  assert.notStrictEqual(diversified[0].authorId, diversified[1].authorId);
});

test('FeedOrchestrator: filters seen items and returns unread feed', async () => {
  const orchestrator = new FeedOrchestrator({
    diversity: { minSpacing: 1 },
    enableShuffle: false
  });

  const candidates = [
    { id: 'v1', authorId: 'a1', baseScore: 10 },
    { id: 'v2', authorId: 'a2', baseScore: 8 },
    { id: 'v3', authorId: 'a3', baseScore: 6 }
  ];

  // First request: all 3 served, marks as seen
  const feed1 = await orchestrator.getFeed({
    userKey: 'test_user',
    candidates,
    limit: 2,
    markAsSeen: true
  });

  assert.strictEqual(feed1.length, 2);
  const servedIds = feed1.map(v => v.id);
  assert.deepStrictEqual(servedIds, ['v1', 'v2']);

  // Second request: v1 and v2 are seen, so v3 is served!
  const feed2 = await orchestrator.getFeed({
    userKey: 'test_user',
    candidates,
    limit: 2,
    markAsSeen: true
  });

  assert.strictEqual(feed2.length, 1);
  assert.strictEqual(feed2[0].id, 'v3');
});
