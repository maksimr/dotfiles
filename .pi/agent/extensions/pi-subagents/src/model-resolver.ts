/**
 * Model resolution: exact match ("provider/modelId") with fuzzy fallback.
 */

import type { ThinkingLevel } from "./types.js";

/**
 * Advertised thinking levels, ordered to mirror pi-ai's EXTENDED_THINKING_LEVELS
 * (`off` + every `ThinkingLevel`). Single source for the Agent tool description,
 * the generated-agent template, the `/agents` wizard and the `model:` suffix parser
 * so these lists can't drift behind pi again (#147). Availability of any level
 * still depends on the host pi version and the selected model — pi clamps
 * unsupported levels down.
 */
export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

/** "gpt-5:high" → { pattern: "gpt-5", thinking: "high" }. A non-level suffix ("llama3:8b") stays part of the id. */
export function splitThinking(entry: string): { pattern: string; thinking?: ThinkingLevel } {
  const i = entry.lastIndexOf(":");
  const level = entry.slice(i + 1);
  return i !== -1 && (THINKING_LEVELS as readonly string[]).includes(level)
    ? { pattern: entry.slice(0, i), thinking: level as ThinkingLevel }
    : { pattern: entry };
}

export interface ModelEntry {
  id: string;
  name: string;
  provider: string;
}

export interface ModelRegistry {
  find(provider: string, modelId: string): any;
  getAll(): any[];
  getAvailable?(): any[];
}

/**
 * Both display forms of a model. The short one goes on tight rows (the widget,
 * the Agent tool result), the canonical one where there is room to disambiguate
 * two providers serving a similarly-named model (the conversation viewer).
 *
 * One function, because `index.ts` labels the model it resolved before the run
 * and `agent-manager.ts` relabels it from the live session afterwards — the two
 * must agree or the label would visibly change the moment the session starts.
 */
export function describeModel(
  model: { provider: string; id: string; name?: string },
): { modelName: string; modelId: string } {
  return {
    modelName: (model.name ?? model.id).replace(/^Claude\s+/i, "").toLowerCase(),
    modelId: `${model.provider}/${model.id}`,
  };
}

/**
 * Resolve a model string to a Model instance.
 * Tries exact match first ("provider/modelId"), then fuzzy match against all available models.
 * Returns the Model on success, or an error message string on failure.
 */
export function resolveModel(
  input: string,
  registry: ModelRegistry,
): any | string {
  const resolved = resolveModelWithFallbacks(input, undefined, registry);
  return typeof resolved === "string" ? resolved : resolved.model;
}

/**
 * resolveModel for `input`, then each "<model>:<thinking>" entry of `fallbacks`
 * in order. Returns the winning fallback's thinking suffix, if any.
 */
export function resolveModelWithFallbacks(
  input: string,
  fallbacks: string[] | undefined,
  registry: ModelRegistry,
): { model: any; thinking?: ThinkingLevel } | string {
  const candidates = [{ pattern: input, thinking: undefined }, ...(fallbacks ?? []).map(splitThinking)];
  // Exact matches across all candidates first, so a loose fuzzy hit on `input`
  // can't shadow an exact fallback. With no fallbacks this is plain resolveModel.
  for (const minScore of [100, 20]) {
    for (const { pattern, thinking } of candidates) {
      const model = matchModel(pattern, registry, minScore);
      if (model) return { model, thinking };
    }
  }

  // No match — list available models
  const all = (registry.getAvailable?.() ?? registry.getAll()) as ModelEntry[];
  const modelList = all
    .map(m => `  ${m.provider}/${m.id}`)
    .sort()
    .join("\n");
  return `Model not found: "${input}".\n\nAvailable models:\n${modelList}`;
}

function matchModel(input: string, registry: ModelRegistry, minScore: number): any | undefined {
  // Available models (those with auth configured)
  const all = (registry.getAvailable?.() ?? registry.getAll()) as ModelEntry[];
  const availableSet = new Set(all.map(m => `${m.provider}/${m.id}`.toLowerCase()));

  // 1. Exact match: "provider/modelId" — only if available (has auth)
  const slashIdx = input.indexOf("/");
  if (slashIdx !== -1) {
    const provider = input.slice(0, slashIdx);
    const modelId = input.slice(slashIdx + 1);
    if (availableSet.has(input.toLowerCase())) {
      const found = registry.find(provider, modelId);
      if (found) return found;
    }
  }

  // 2. Fuzzy match against available models. Normalize separators so cosmetic
  // punctuation differences still match — e.g. "claude-haiku-4.5" and
  // "claude-haiku-4-5" (dot vs dash in the version) resolve to the same model.
  const normalize = (s: string) => s.toLowerCase().replace(/\./g, "-");
  const query = normalize(input);

  // Score each model: prefer exact id match > id contains > name contains > provider+id contains
  let bestMatch: ModelEntry | undefined;
  let bestScore = 0;

  for (const m of all) {
    const id = normalize(m.id);
    const name = normalize(m.name);
    const full = normalize(`${m.provider}/${m.id}`);

    let score = 0;
    if (id === query || full === query) {
      score = 100; // exact
    } else if (id.includes(query) || full.includes(query)) {
      score = 60 + (query.length / id.length) * 30; // substring, prefer tighter matches
    } else if (name.includes(query)) {
      score = 40 + (query.length / name.length) * 20;
    } else if (
      // A trailing date-stamp token (e.g. "20251001") is optional, so a
      // date-pinned config like "claude-haiku-4-5-20251001" still matches an
      // undated registry id like "claude-haiku-4-5".
      query
        .split(/[\s\-/]+/)
        .every(part => /^\d{8}$/.test(part) || id.includes(part) || name.includes(part) || m.provider.toLowerCase().includes(part))
    ) {
      score = 20; // all parts present somewhere
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = m;
    }
  }

  if (bestMatch && bestScore >= minScore) {
    const found = registry.find(bestMatch.provider, bestMatch.id);
    if (found) return found;
  }

  // 3. Provider fallback: a "provider/modelId" query that didn't match under the
  // named provider (exact or fuzzy above) retries against all providers. The
  // named provider is preferred when present; this only kicks in when it isn't,
  // so the same model from another provider beats falling back to "inherit".
  // Skipped in the exact pass so a named provider still beats another one's exact id.
  if (slashIdx !== -1 && minScore < 100) {
    return matchModel(input.slice(slashIdx + 1), registry, minScore);
  }
  return undefined;
}
