/**
 * @vayu/recsys-core
 * Zero-cost, low-latency, plug-and-play recommendation and de-duplication engine.
 */

import { FeedOrchestrator } from './src/FeedOrchestrator.js';

export { FeedOrchestrator };
export { CandidatePool } from './src/candidatePool.js';

// Stores
export { ISeenStore } from './src/stores/ISeenStore.js';
export { MemorySeenStore } from './src/stores/MemorySeenStore.js';
export { RedisSeenStore } from './src/stores/RedisSeenStore.js';

// Evaluators & Formulas
export { WilsonScorer } from './src/evaluators/WilsonScorer.js';
export { DecayFormula } from './src/evaluators/DecayFormula.js';

// Rerankers
export { DiversityReranker } from './src/rerankers/DiversityReranker.js';
export { WeightedShuffler } from './src/rerankers/WeightedShuffler.js';

export default FeedOrchestrator;
