# @vayu/recsys-core

A zero-cost, low-latency (<5ms), plug-and-play recommendation and de-duplication engine for Node.js.

Designed to eliminate repeated feed items (Instagram/TikTok style) and minimize database queries without requiring paid cloud vector databases or expensive Redis tiers.

## Features
- **30-Day Seen De-duplication**: Guarantees users never see recently viewed content again.
- **₹0 In-Memory Store**: Zero external dependencies; uses LRU RAM storage if Redis is unavailable.
- **Pluggable Redis Support**: Automatically uses Redis sets with in-memory fallback.
- **Dynamic Evaluators**: Fully customizable scoring formulas (Wilson engagement, time decay, personalized interest vectors).
- **Anti-Fatigue Diversity**: Prevents same-creator/category clumping.
- **Stochastic Weighted Shuffling**: Keeps the feed dynamic and engaging upon every refresh.

## Quick Start (Any Node.js App)

```javascript
import { FeedOrchestrator, WilsonScorer, DecayFormula } from '@vayu/recsys-core';

// 1. Initialize Orchestrator
const orchestrator = new FeedOrchestrator({
  diversity: { minSpacing: 3 }, // Minimum 3 items between same author
  seenTtlSeconds: 30 * 24 * 60 * 60 // 30 days
});

// 2. Add Dynamic Evaluators (Optional)
orchestrator.addEvaluator(async (item, context) => {
  const wilson = WilsonScorer.score(item.likes, item.views);
  const decay = DecayFormula.recencyDecay(item.createdAt);
  return (wilson * 0.6 + decay * 0.4);
});

// 3. Get Fresh Feed
const feed = await orchestrator.getFeed({
  userKey: req.user.id,
  candidates: poolOfVideos,
  excludeIds: req.query.excludeIds,
  limit: 10
});
```
