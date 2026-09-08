import { spawn } from 'node:child_process';

import { appendHistory, readHistory } from './history.js';
import { loadProjectContext } from './context.js';
import {
  buildCritiquePrompt,
  buildCustomPrompt,
  buildGenericCritiquePrompt,
  buildPrompt,
  buildTopicPrompt,
  buildTrendingPrompt,
  sampleTopicTerritory,
} from './prompt.js';
import { generateWithProvider } from './providers.js';
import { research } from './research.js';
import { isCategory, researchTrending } from './trending.js';
import {
  DEFAULT_PROVIDER,
  PLATFORMS,
  PROVIDERS,
  TOPIC_BANK,
  TRENDING_CATEGORIES,
} from './config.js';
import { saveOutput } from './output.js';

const HELP = `Snehayog/Vayug Post Agent

Single post (with Snehayog/Vayug context):
  node generate.js linkedin
  node generate.js linkedin "creator monetization"
  node generate.js --platform reddit --topic "video discovery"
  node generate.js x "short-form creator revenue" --provider codex --copy

Custom / Generic post (NO Vayug/Snehayog context or promotion):
  node generate.js custom
  node generate.js custom AI
  node generate.js custom AI linkedin
  node generate.js custom "productivity tips" linkedin
  node generate.js custom technology x --provider opencode
  node generate.js custom startup reddit --count 3

Loop:
  node auto-generate.js --loop --count 10 --interval 50
  node auto-generate.js --platform all --provider opencode --count 4
  node auto-generate.js custom AI --loop --count 5 --interval 60

Options:
  --provider <name>   ${PROVIDERS.join(' | ')} (default: ${DEFAULT_PROVIDER})
  --platform <name>   ${PLATFORMS.join(' | ')} | all
  --topic <text>      skip topic discovery and use this topic
  --count <n>         how many posts to generate
  --interval <sec>    wait between posts in a loop
  --loop              keep generating until --count is reached
  --copy              copy the finished post to the clipboard
  --no-critique       skip the editor pass (halves provider calls, lower quality)

Trending Categories:
  ${Object.keys(TRENDING_CATEGORIES).join(', ')}

Environment:
  POST_AGENT_PROJECT_ROOT   project path (auto-detected from the agent location)
  TAVILY_API_KEY            preferred web search provider
  no key                    DuckDuckGo HTML fallback
`;

function valueAfter(args, index, flag) {
  const value = args[index + 1];
  if (!value || value.startsWith('--')) throw new Error(`${flag} needs a value`);
  return value;
}

export function parseArgs(argv, mode = 'single') {
  const args = {
    mode,
    provider: DEFAULT_PROVIDER,
    platform: mode === 'single' ? 'linkedin' : 'all',
    topic: null,
    count: 1,
    loop: false,
    interval: 120,
    copy: false,
    critique: true,
    help: false,
    trending: false,
    custom: false,
    category: null,
  };
  const positionals = [];

  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') args.help = true;
    else if (arg === '--provider') args.provider = valueAfter(argv, i++, '--provider');
    else if (arg === '--platform') args.platform = valueAfter(argv, i++, '--platform');
    else if (arg === '--topic') args.topic = valueAfter(argv, i++, '--topic');
    else if (arg === '--count') args.count = Number(valueAfter(argv, i++, '--count'));
    else if (arg === '--interval') args.interval = Number(valueAfter(argv, i++, '--interval'));
    else if (arg === '--loop') args.loop = true;
    else if (arg === '--copy') args.copy = true;
    else if (arg === '--no-critique') args.critique = false;
    else if (arg.startsWith('--')) throw new Error(`unknown option: ${arg}`);
    else positionals.push(arg);
  }

  if (positionals[0]?.toLowerCase() === 'custom') {
    positionals.shift();
    args.custom = true;
    args.mode = 'custom';

    // Scan remaining positionals for platform, category, or topic
    for (let i = 0; i < positionals.length; i++) {
      const p = positionals[i];
      const pLower = p.toLowerCase();
      if (!args.category && isCategory(pLower)) {
        args.category = pLower;
        positionals.splice(i, 1);
        i--;
      } else if (PLATFORMS.includes(pLower) || pLower === 'all') {
        args.platform = pLower;
        positionals.splice(i, 1);
        i--;
      }
    }

    // Anything left over in positionals is a topic phrase
    if (positionals.length > 0) {
      args.topic = [args.topic, ...positionals].filter(Boolean).join(' ');
      positionals.length = 0;
    }

    // If no topic and no category was specified, default to a trending category
    if (!args.topic && !args.category) {
      args.trending = true;
      const categories = Object.keys(TRENDING_CATEGORIES);
      args.category = categories[Math.floor(Math.random() * categories.length)];
    } else if (args.category) {
      args.trending = true;
    }
  } else {
    // Normal Vayug post flow
    if (positionals[0] && (PLATFORMS.includes(positionals[0]) || positionals[0] === 'all')) {
      args.platform = positionals.shift();
    }
    if (positionals.length > 0) {
      args.topic = [args.topic, ...positionals].filter(Boolean).join(' ');
    }
  }

  if (!PROVIDERS.includes(args.provider)) throw new Error(`unknown provider: ${args.provider}`);
  if (![...PLATFORMS, 'all'].includes(args.platform)) throw new Error(`unknown platform: ${args.platform}`);
  if (!Number.isInteger(args.count) || args.count < 1) throw new Error('--count must be a positive integer');
  if (!Number.isFinite(args.interval) || args.interval < 0) throw new Error('--interval must be zero or greater');
  return args;
}

const normalizeTopic = (value) => (value || '').trim().toLowerCase();

function fallbackTopic(index, history) {
  // Compare normalized: a discovered topic is stored with the provider's own
  // capitalization, so an exact-string check would re-serve a used topic.
  const used = new Set(history.map((item) => normalizeTopic(item.topic)));
  const available = TOPIC_BANK.filter((item) => !used.has(normalizeTopic(item)));
  return (available.length ? available : TOPIC_BANK)[index % (available.length || TOPIC_BANK.length)];
}

function cleanSuggestedTopic(value) {
  return value
    .split(/\r?\n/)[0]
    .replace(/^[-*#\d.)\s]+/, '')
    .replace(/^['"`]|['"`]$/g, '')
    .replace(/[.!?]+$/, '')
    .trim();
}

async function chooseTopic({ topic, index, args, state }) {
  if (topic) return topic;
  const platform = choosePlatform(args.platform, index);
  console.log(`  discovering a fresh ${platform} topic...`);
  try {
    const suggestion = await generateWithProvider(
      buildTopicPrompt({
        platform,
        context: state.context,
        history: state.history,
        territory: sampleTopicTerritory(TOPIC_BANK),
      }),
      args.provider,
    );
    const cleaned = cleanSuggestedTopic(suggestion);
    const key = normalizeTopic(cleaned);
    const duplicate = state.history.some((item) => normalizeTopic(item.topic) === key);
    // The territory sample is meant to steer, not to be copied back. If the
    // provider just echoes a bank entry, fall through to the rotation instead —
    // discovery only earns its extra call when it produces a new angle.
    const echoedTerritory = TOPIC_BANK.some((item) => normalizeTopic(item) === key);
    if (echoedTerritory) console.log('  discovery echoed the topic bank; using the rotation instead');
    if (cleaned && !duplicate && !echoedTerritory && cleaned.split(/\s+/).length >= 3) return cleaned;
  } catch (error) {
    console.log(`  topic discovery unavailable (${error.message}); using the built-in topic rotation`);
  }
  return fallbackTopic(index, state.history);
}

function choosePlatform(platform, index) {
  return platform === 'all' ? PLATFORMS[index % PLATFORMS.length] : platform;
}

async function copyToClipboard(text) {
  if (process.platform === 'win32') {
    await runClipboard('clip', [], text);
  } else if (process.platform === 'darwin') {
    await runClipboard('pbcopy', [], text);
  } else {
    await runClipboard('xclip', ['-selection', 'clipboard'], text);
  }
}

function runClipboard(command, args, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { windowsHide: true });
    let stderr = '';
    child.stderr.on('data', (chunk) => (stderr += chunk));
    child.on('error', (error) => reject(new Error(`clipboard command unavailable: ${error.message}`)));
    child.on('close', (code) => code === 0 ? resolve() : reject(new Error(stderr.trim() || `clipboard exited with ${code}`)));
    child.stdin.end(input);
  });
}

function stripFences(text) {
  return text.replace(/^```(?:markdown|text)?\s*/i, '').replace(/\s*```$/i, '').trim();
}

// Second pass over the draft. A failure here must never cost us a good post,
// so anything short of a non-empty revision falls back to the original.
async function critique({ platform, topic, context, post, provider, isCustom = false }) {
  try {
    const prompt = isCustom
      ? buildGenericCritiquePrompt({ platform, topic, post })
      : buildCritiquePrompt({ platform, topic, context, post });
    const revised = stripFences(
      await generateWithProvider(prompt, provider),
    );
    if (!revised) {
      console.log('  editor pass returned nothing; keeping the original draft');
      return post;
    }
    console.log(revised === post ? '  editor pass: no changes' : '  editor pass: revised');
    return revised;
  } catch (error) {
    console.log(`  editor pass unavailable (${error.message}); keeping the original draft`);
    return post;
  }
}

async function generateOne(args, index, state) {
  const platform = choosePlatform(args.platform, index);
  const topic = await chooseTopic({ topic: args.topic, index, args, state });
  console.log(`\n[${index + 1}] researching "${topic}" for ${platform} (${args.provider})...`);
  const webResearch = await research({ topic, projectName: 'Snehayog/Vayug' });
  const prompt = buildPrompt({
    platform,
    topic,
    context: state.context,
    research: webResearch,
    history: state.history,
  });
  const draft = stripFences(await generateWithProvider(prompt, args.provider));
  if (!draft) throw new Error(`${args.provider} returned an empty post`);
  const post = args.critique
    ? await critique({ platform, topic, context: state.context, post: draft, provider: args.provider, isCustom: false })
    : draft;
  const directory = await saveOutput({ platform, topic, provider: args.provider, post, research: webResearch, context: state.context });
  const entry = { createdAt: new Date().toISOString(), platform, topic, provider: args.provider, directory };
  await appendHistory(entry);
  state.history.push(entry);
  console.log(`\n${post}\n\nSaved: ${directory}`);
  if (args.copy) {
    await copyToClipboard(post);
    console.log('Copied post to clipboard.');
  }
}

async function generateTrending(args, index, state) {
  const platform = choosePlatform(args.platform, index);

  console.log(`\n[${index + 1}] researching trending ${args.category} news for ${platform}...`);

  const trending = await researchTrending(args.category);
  console.log(`  found trending topic: "${trending.topic}"`);

  const webResearch = await research({ topic: trending.topic, projectName: args.custom ? null : 'Snehayog/Vayug' });
  const prompt = buildTrendingPrompt({
    platform,
    category: trending.category,
    topic: trending.topic,
    newsItems: trending.newsItems,
    suggestedHashtags: trending.suggestedHashtags,
    context: state.context,
    research: webResearch,
    history: state.history,
    isCustom: Boolean(args.custom),
  });
  const draft = stripFences(await generateWithProvider(prompt, args.provider));
  if (!draft) throw new Error(`${args.provider} returned an empty post`);
  const post = args.critique
    ? await critique({
        platform,
        topic: trending.topic,
        context: state.context,
        post: draft,
        provider: args.provider,
        isCustom: Boolean(args.custom),
      })
    : draft;
  const directory = await saveOutput({
    platform,
    topic: `[${args.category}] ${trending.topic}`,
    provider: args.provider,
    post,
    research: webResearch,
    context: state.context,
  });
  const entry = { createdAt: new Date().toISOString(), platform, topic: trending.topic, provider: args.provider, directory };
  await appendHistory(entry);
  state.history.push(entry);
  console.log(`\n${post}\n\nSaved: ${directory}`);
  if (args.copy) {
    await copyToClipboard(post);
    console.log('Copied post to clipboard.');
  }
}

async function generateCustomTopic(args, index, state) {
  const platform = choosePlatform(args.platform, index);
  const topic = args.topic;
  console.log(`\n[${index + 1}] researching custom topic "${topic}" for ${platform} (${args.provider})...`);

  const webResearch = await research({ topic, projectName: null });
  const prompt = buildCustomPrompt({
    platform,
    topic,
    research: webResearch,
    history: state.history,
  });
  const draft = stripFences(await generateWithProvider(prompt, args.provider));
  if (!draft) throw new Error(`${args.provider} returned an empty post`);
  const post = args.critique
    ? await critique({
        platform,
        topic,
        context: { text: '', files: [] },
        post: draft,
        provider: args.provider,
        isCustom: true,
      })
    : draft;
  const directory = await saveOutput({
    platform,
    topic,
    provider: args.provider,
    post,
    research: webResearch,
    context: state.context,
  });
  const entry = { createdAt: new Date().toISOString(), platform, topic, provider: args.provider, directory };
  await appendHistory(entry);
  state.history.push(entry);
  console.log(`\n${post}\n\nSaved: ${directory}`);
  if (args.copy) {
    await copyToClipboard(post);
    console.log('Copied post to clipboard.');
  }
}

export async function runCli(mode) {
  if (mode === 'context') {
    const context = await loadProjectContext();
    console.log(`Project root: ${context.projectRoot}\nFiles: ${context.files.join(', ')}`);
    return;
  }
  const args = parseArgs(process.argv, mode);
  if (args.help) {
    console.log(HELP);
    return;
  }
  const context = args.custom ? { text: '', files: [] } : await loadProjectContext();
  const state = { context, history: await readHistory() };
  const total = args.count;

  if (args.custom) {
    if (args.trending) {
      console.log(`Post Agent | mode: custom (trending) | category: ${args.category} | provider: ${args.provider} | platform: ${args.platform}`);
    } else {
      console.log(`Post Agent | mode: custom (generic) | topic: ${args.topic} | provider: ${args.provider} | platform: ${args.platform}`);
    }
  } else if (args.trending) {
    console.log(`Post Agent | mode: trending | category: ${args.category} | provider: ${args.provider} | platform: ${args.platform}`);
  } else {
    console.log(`Post Agent | provider: ${args.provider} | platform: ${args.platform} | search: enabled`);
  }

  let generated = 0;
  let attempts = 0;
  while (generated < total) {
    try {
      if (args.custom && !args.trending && args.topic) {
        await generateCustomTopic(args, attempts, state);
      } else if (args.trending) {
        await generateTrending(args, attempts, state);
      } else {
        await generateOne(args, attempts, state);
      }
      generated++;
    } catch (error) {
      console.error(`Generation failed: ${error.message}`);
      if (!args.loop) process.exitCode = 1;
      if (!args.loop) break;
    }
    attempts++;
    if (args.loop && generated < total) {
      console.log(`Waiting ${args.interval}s before the next post...`);
      await new Promise((resolve) => setTimeout(resolve, args.interval * 1000));
    }
  }
}

if (process.argv[1]?.endsWith('src\\cli.js') || process.argv[1]?.endsWith('src/cli.js')) {
  await runCli(process.argv[2] === 'context' ? 'context' : 'single');
}
