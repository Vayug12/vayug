import test from 'node:test';
import assert from 'node:assert/strict';

import { buildQueries } from '../src/research.js';
import { DEFAULT_PROVIDER, PROJECT_ROOT } from '../src/config.js';
import { parseArgs } from '../src/cli.js';
import { buildCustomPrompt, buildGenericCritiquePrompt, buildTrendingPrompt } from '../src/prompt.js';

test('defaults to opencode and points to the sibling snehayog project', () => {
  assert.equal(DEFAULT_PROVIDER, 'opencode');
  assert.match(PROJECT_ROOT, /snehayog$/i);
});

test('builds multiple research queries around the requested topic with projectName', () => {
  const queries = buildQueries({ topic: 'creator monetization', projectName: 'Snehayog/Vayug' });
  assert.equal(queries.length, 3);
  assert.ok(queries.every((query) => query.includes('creator monetization')));
  assert.ok(queries.some((query) => query.includes('Snehayog/Vayug')));
});

test('builds generic research queries without projectName in custom mode', () => {
  const queries = buildQueries({ topic: 'artificial intelligence news', projectName: null });
  assert.equal(queries.length, 3);
  assert.ok(queries.every((query) => query.includes('artificial intelligence news')));
  assert.ok(queries.every((query) => !query.toLowerCase().includes('snehayog')));
  assert.ok(queries.every((query) => !query.toLowerCase().includes('vayug')));
});

test('parseArgs: standard command preserves project mode', () => {
  const args = parseArgs(['node', 'generate.js', 'linkedin', 'creator monetization']);
  assert.equal(args.custom, false);
  assert.equal(args.platform, 'linkedin');
  assert.equal(args.topic, 'creator monetization');
});

test('parseArgs: "custom" alone enables custom mode and selects trending category', () => {
  const args = parseArgs(['node', 'generate.js', 'custom']);
  assert.equal(args.custom, true);
  assert.equal(args.trending, true);
  assert.ok(args.category);
  assert.equal(args.platform, 'linkedin');
});

test('parseArgs: "custom AI" parses category', () => {
  const args = parseArgs(['node', 'generate.js', 'custom', 'AI']);
  assert.equal(args.custom, true);
  assert.equal(args.trending, true);
  assert.equal(args.category, 'ai');
});

test('parseArgs: "custom AI linkedin" parses category and platform', () => {
  const args = parseArgs(['node', 'generate.js', 'custom', 'AI', 'linkedin']);
  assert.equal(args.custom, true);
  assert.equal(args.trending, true);
  assert.equal(args.category, 'ai');
  assert.equal(args.platform, 'linkedin');
});

test('parseArgs: "custom <topic> <platform>" parses custom topic and platform', () => {
  const args = parseArgs(['node', 'generate.js', 'custom', 'productivity tips for remote teams', 'x']);
  assert.equal(args.custom, true);
  assert.equal(args.trending, false);
  assert.equal(args.topic, 'productivity tips for remote teams');
  assert.equal(args.platform, 'x');
});

test('buildTrendingPrompt in custom mode contains strict non-promotion instructions and no Vayug facts', () => {
  const prompt = buildTrendingPrompt({
    platform: 'linkedin',
    category: 'AI & Machine Learning',
    topic: 'Agentic AI Workflows',
    newsItems: [{ title: 'New Agents Released', snippet: 'State of the art agent systems' }],
    suggestedHashtags: ['#AI', '#MachineLearning'],
    context: { text: 'Some Vayug context that should not be used in custom mode' },
    research: { results: [{ title: 'AI News', url: 'https://example.com', snippet: 'Evidence' }] },
    history: [],
    isCustom: true,
  });

  assert.ok(prompt.includes('STRICTLY NO PROMOTION'));
  assert.ok(!prompt.includes('Some Vayug context that should not be used in custom mode'));
  assert.ok(!prompt.includes('connect it to the project'));
});

test('buildCustomPrompt contains strict non-promotion instructions', () => {
  const prompt = buildCustomPrompt({
    platform: 'x',
    topic: 'The Future of Remote Work',
    research: { results: [] },
    history: [],
  });

  assert.ok(prompt.includes('STRICTLY NO PROMOTION'));
  assert.ok(!prompt.includes('Vayug'));
  assert.ok(!prompt.includes('Snehayog'));
});

test('buildGenericCritiquePrompt checks against app promotion', () => {
  const prompt = buildGenericCritiquePrompt({
    platform: 'linkedin',
    topic: 'Micro-SaaS ideas',
    post: 'Here is a post about micro-saas.',
  });

  assert.ok(prompt.includes('STRICTLY NON-PROMOTIONAL'));
  assert.ok(!prompt.includes('Every product claim in the post must be supported by this context'));
});
