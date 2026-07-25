// Headroom Pi extension — compresses large tool outputs via Headroom (CCR-reversible).
// https://github.com/headroomlabs-ai/headroom
//
// Requires: headroom CLI installed by the user (pip/uv: `headroom-ai[all]`).
// This extension does NOT install headroom. If the CLI is missing, it disables itself.
//
// How it works:
//   - Spawns a long-lived `headroom mcp serve` (stdio MCP server, local-only).
//   - On tool_result, large text outputs are compressed via `headroom_compress`.
//     Originals are stored in Headroom's local CCR store.
//   - Registers a `headroom_retrieve` tool so the LLM can recover any original
//     by hash — compression is fully reversible, the agent never loses data.
//   - Fails open: any error/timeout passes the original output through untouched.
//
// Config (env):
//   HEADROOM_PI_DISABLED=1        disable entirely
//   HEADROOM_PI_TOOLS             comma list of tools whose FRESH output is compressed
//                                 (default: "web_search,fetch_content,get_search_content")
//                                 Deliberately narrow — see "Fresh vs stale" below.
//                                 NOTE: do NOT add "read" — edit.oldText must match
//                                 file contents exactly; compressing reads breaks edits.
//                                 (Stale reads are still compressed via history compression,
//                                 and duplicate reads are deduped — see below.)
//   HEADROOM_PI_MIN_CHARS         min output size to compress (default: 2500)
//   HEADROOM_PI_MIN_SAVINGS_PCT   keep original unless savings >= this (default: 10). The
//                                 retrieval marker's own cost is subtracted on top, so a
//                                 block is only replaced when it is a net token win.
//   HEADROOM_PI_TIMEOUT_MS        per-compression timeout (default: 20000)
//   HEADROOM_PI_DEBUG=1           log MCP server stderr
//   HEADROOM_PI_CONTEXT=0         disable history compression (context event)
//   HEADROOM_PI_MIN_CONTEXT_TOKENS  history compression kicks in at this context size (default: 10000)
//   HEADROOM_PI_KEEP_RECENT       never compress the last N history messages (default: 4)
//   HEADROOM_PI_MAX_PER_TURN      max new compressions per LLM call (default: 3).
//                                 Sets the startup value; change it live with
//                                 `/headroom batch <n>`.
//
// Read dedup: a repeat `read` of a file whose content hasn't changed is replaced
// with a short marker (destructive, in-history — safe because the identical full
// text already exists earlier in history and is retrievable via headroom_retrieve).
//
// Fresh vs stale: compressing FRESH tool output is the risky half of this extension.
// It hits exactly when the model is about to act on the result, and one unnecessary
// headroom_retrieve costs a round trip plus the full original re-entering context
// (protected for KEEP_RECENT*3 messages) — wiping out many compressions. So the
// default tool list is limited to research payloads: fat, prose-shaped, and rarely
// needed byte-exact. Tools whose output the model parses for exact strings (bash,
// grep line numbers, find paths) are left alone; history compression still shrinks
// them once they go stale, at no fidelity risk.
//
// TODO: consider dropping the fresh-output path entirely and relying on history
// compression alone. History compression is non-destructive and strictly safer;
// the only thing the fresh path buys is savings on the turn the output arrives.
// Worth measuring before removing — if `/headroom` shows most savings coming from
// the context handler, delete the tool_result compression branch.
//
// History compression (idea borrowed from @raquezha/noheadroom): pi's `context`
// event provides a deep copy of messages, mutated per-request only — the real
// session history keeps the originals. So compressing stale toolResult messages
// (including `read` outputs) is safe: worst case the model re-reads the file.
// Compressed text is cached by content hash, so each unique output costs one
// MCP call and is a cheap lookup on every later turn.

import { spawn, type ChildProcess } from 'node:child_process';
import { createHash } from 'node:crypto';
import type { ContextEvent, ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Type } from 'typebox';

type AgentMessage = ContextEvent['messages'][number];

const RETRIEVE_TOOL = 'headroom_retrieve';
const PROBE_TIMEOUT_MS = 10_000;
const INIT_TIMEOUT_MS = 30_000;

const DISABLED = process.env.HEADROOM_PI_DISABLED === '1';
const CONTEXT_DISABLED = process.env.HEADROOM_PI_CONTEXT === '0';
const MIN_CONTEXT_TOKENS = intEnv('HEADROOM_PI_MIN_CONTEXT_TOKENS', 10_000);
const KEEP_RECENT = intEnv('HEADROOM_PI_KEEP_RECENT', 4);
const MAX_PER_TURN = intEnv('HEADROOM_PI_MAX_PER_TURN', 3);
const MAX_CACHE_ENTRIES = 256;
const DEBUG = process.env.HEADROOM_PI_DEBUG === '1';
const MIN_CHARS = intEnv('HEADROOM_PI_MIN_CHARS', 2500);
const MIN_SAVINGS_PCT = intEnv('HEADROOM_PI_MIN_SAVINGS_PCT', 10);
const COMPRESS_TIMEOUT_MS = intEnv('HEADROOM_PI_TIMEOUT_MS', 20_000);
const COMPRESS_TOOLS = new Set(
  (process.env.HEADROOM_PI_TOOLS ?? 'web_search,fetch_content,get_search_content')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
);

function intEnv(name: string, fallback: number): number {
  const n = parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function debugLog(...args: unknown[]) {
  if (DEBUG) console.warn('[headroom]', ...args);
}

// ---------------------------------------------------------------------------
// Minimal MCP stdio client for `headroom mcp serve`
// (newline-delimited JSON-RPC 2.0)
// ---------------------------------------------------------------------------

interface Pending {
  resolve: (v: unknown) => void;
  reject: (e: Error) => void;
}

class HeadroomMcp {
  private child: ChildProcess | null = null;
  private ready: Promise<void> | null = null;
  private pending = new Map<number, Pending>();
  private nextId = 1;
  private buffer = '';
  dead = false;

  /** Start server + MCP handshake. Idempotent. */
  start(): Promise<void> {
    if (this.dead) return Promise.reject(new Error('headroom mcp server is dead'));
    if (this.ready) return this.ready;
    this.ready = this.doStart();
    return this.ready;
  }

  private doStart(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.markDead('initialize timed out');
        reject(new Error('headroom mcp serve: initialize timed out'));
      }, INIT_TIMEOUT_MS);

      let child: ChildProcess;
      try {
        child = spawn('headroom', ['mcp', 'serve'], {
          stdio: ['pipe', 'pipe', 'pipe'],
          env: process.env
        });
      } catch (err) {
        clearTimeout(timer);
        this.markDead(String(err));
        reject(err as Error);
        return;
      }
      this.child = child;

      child.on('error', (err) => {
        clearTimeout(timer);
        this.markDead(`spawn error: ${err.message}`);
        reject(err);
      });
      child.on('exit', (code) => {
        clearTimeout(timer);
        this.markDead(`server exited (code=${code})`);
        reject(new Error(`headroom mcp serve exited (code=${code})`));
      });
      child.stderr?.on('data', (d: Buffer) => debugLog('stderr:', d.toString().trim()));
      child.stdout?.on('data', (d: Buffer) => this.onData(d));

      // MCP handshake: initialize -> (response) -> notifications/initialized
      this.request('initialize', {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: { name: 'pi-headroom-extension', version: '1.0.0' }
      })
        .then(() => {
          this.notify('notifications/initialized', {});
          clearTimeout(timer);
          resolve();
        })
        .catch((err) => {
          clearTimeout(timer);
          this.markDead(`initialize failed: ${err}`);
          reject(err);
        });
    });
  }

  private markDead(reason: string) {
    if (this.dead) return;
    this.dead = true;
    debugLog('server dead:', reason);
    for (const p of this.pending.values()) p.reject(new Error(`headroom mcp: ${reason}`));
    this.pending.clear();
    this.child?.kill();
    this.child = null;
  }

  private onData(chunk: Buffer) {
    this.buffer += chunk.toString();
    let nl: number;
    while ((nl = this.buffer.indexOf('\n')) !== -1) {
      const line = this.buffer.slice(0, nl).trim();
      this.buffer = this.buffer.slice(nl + 1);
      if (!line) continue;
      try {
        const msg = JSON.parse(line);
        if (typeof msg.id === 'number' && this.pending.has(msg.id)) {
          const p = this.pending.get(msg.id)!;
          this.pending.delete(msg.id);
          if (msg.error) p.reject(new Error(msg.error.message ?? JSON.stringify(msg.error)));
          else p.resolve(msg.result);
        }
      } catch {
        debugLog('unparseable line from server:', line.slice(0, 200));
      }
    }
  }

  private write(obj: unknown): void {
    const stdin = this.child?.stdin;
    if (!stdin || !stdin.writable) throw new Error('headroom mcp: stdin not writable');
    stdin.write(JSON.stringify(obj) + '\n');
  }

  private notify(method: string, params: unknown): void {
    this.write({ jsonrpc: '2.0', method, params });
  }

  private request(method: string, params: unknown): Promise<unknown> {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      try {
        this.write({ jsonrpc: '2.0', id, method, params });
      } catch (err) {
        this.pending.delete(id);
        reject(err as Error);
      }
    });
  }

  /** Call an MCP tool; returns the parsed JSON payload of the first text block. */
  async callTool(
    name: string,
    args: Record<string, unknown>,
    timeoutMs: number,
    signal?: AbortSignal
  ): Promise<Record<string, unknown>> {
    await this.start();
    const call = this.request('tools/call', { name, arguments: args });

    const result = (await withTimeout(call, timeoutMs, signal)) as {
      content?: Array<{ type: string; text?: string }>;
      isError?: boolean;
    };
    const text = result?.content?.find((c) => c.type === 'text')?.text;
    if (!text) throw new Error(`headroom ${name}: empty response`);
    const payload = JSON.parse(text) as Record<string, unknown>;
    if (result.isError || payload.error) {
      throw new Error(String(payload.error ?? `headroom ${name} failed`));
    }
    return payload;
  }

  shutdown() {
    this.markDead('shutdown');
  }
}

function withTimeout<T>(promise: Promise<T>, ms: number, signal?: AbortSignal): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timed out after ${ms}ms`)), ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(new Error('aborted'));
    };
    signal?.addEventListener('abort', onAbort, { once: true });
    promise.then(resolve, reject).finally(() => {
      clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
    });
  });
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default async function (pi: ExtensionAPI) {
  if (DISABLED) return;

  const mcp = new HeadroomMcp();
  let enabled = false; // headroom CLI found (probe succeeded)
  let active = true; // user toggle via /headroom on|off
  let batchSize = MAX_PER_TURN; // new compressions per LLM call; /headroom batch <n>

  // Footer status: a simple "headroom: on|off" indicator (no stats).
  let compressions = 0;
  let tokensSaved = 0;
  const updateStatus = (ctx: {
    ui: { setStatus(key: string, text?: string): void; theme: { fg(color: 'dim', text: string): string } };
  }) => {
    if (!enabled) return;
    const text = mcp.dead || !active ? 'headroom: off' : 'headroom: on';
    ctx.ui.setStatus('headroom', ctx.ui.theme.fg('dim', text));
  };

  // Probe headroom CLI in the background — never block pi startup on a
  // (slow, Python) CLI. Tool registration happens once the probe succeeds.
  const probe = (async () => {
    const ver = await pi.exec('headroom', ['--version'], { timeout: PROBE_TIMEOUT_MS });
    if (ver.code !== 0) {
      console.warn('[headroom] headroom CLI not found in PATH — extension disabled');
      return false;
    }
    debugLog('found', ver.stdout.trim());
    registerRetrieveTool(pi, mcp);
    enabled = true;
    return true;
  })().catch((err) => {
    console.warn('[headroom] probe failed — extension disabled', err);
    return false;
  });

  pi.on('session_shutdown', () => mcp.shutdown());

  pi.on('session_start', (_event, ctx) => {
    // Don't block session start on the probe; set status when it resolves.
    void probe.then((ok) => ok && updateStatus(ctx));
  });

  const SUBCOMMANDS = ['stats', 'on', 'off', 'batch'] as const;
  pi.registerCommand('headroom', {
    description: 'Headroom compression. Usage: /headroom [stats|on|off|batch <n>]',
    getArgumentCompletions: (prefix) =>
      SUBCOMMANDS.filter((c) => c.startsWith(prefix.trim().toLowerCase())).map((c) => ({
        value: c,
        label: c
      })),
    handler: async (args, ctx) => {
      const [sub, arg] = args.trim().toLowerCase().split(/\s+/);
      if (!(await probe)) {
        ctx.ui.notify('headroom CLI not available', 'warning');
        return;
      }
      switch (sub) {
        case 'on':
        case 'off':
          active = sub === 'on';
          updateStatus(ctx);
          ctx.ui.notify(`headroom compression ${sub}`, 'info');
          return;
        case 'stats':
          try {
            const stats = await mcp.callTool('headroom_stats', {}, COMPRESS_TIMEOUT_MS);
            ctx.ui.notify(JSON.stringify(stats, null, 2), 'info');
          } catch (err) {
            ctx.ui.notify(`headroom stats failed: ${err}`, 'error');
          }
          return;
        case 'batch': {
          if (!arg) {
            ctx.ui.notify(`headroom batch: ${batchSize} new compressions per LLM call`, 'info');
            return;
          }
          // Number() rejects junk like "3abc" and "3.5" that parseInt would accept.
          const n = Number(arg);
          if (!Number.isInteger(n) || n < 1) {
            ctx.ui.notify(`invalid batch size "${arg}" — expected a positive integer`, 'warning');
            return;
          }
          batchSize = n;
          ctx.ui.notify(`headroom batch set to ${n} new compressions per LLM call`, 'info');
          return;
        }
        default: {
          const fmt = (n: number) => n.toLocaleString();
          ctx.ui.notify(
            [
              `headroom: ${mcp.dead ? 'server dead' : active ? 'on' : 'off'}`,
              `session: ${compressions} compressions, ~${fmt(tokensSaved)} tokens saved`,
              `batch: ${batchSize} new compressions per LLM call`,
              'usage: /headroom [stats|on|off|batch <n>]'
            ].join('\n'),
            'info'
          );
        }
      }
    }
  });

  // Read dedup: seen-read key → CCR hash of the full content (null = seen once,
  // hash created lazily on the first duplicate).
  const readSeen = new BoundedMap<{ hash: string } | null>();

  pi.on('tool_result', async (event, ctx) => {
    try {
      if (!enabled || !active || mcp.dead) return;
      if (event.isError) return; // keep error output exact

      if (event.toolName === 'read') {
        return await dedupRead(mcp, readSeen, event, ctx.signal);
      }

      if (!COMPRESS_TOOLS.has(event.toolName)) return;
      if (event.toolName === RETRIEVE_TOOL) return;

      // Fresh-output compression. Narrow by design (see "Fresh vs stale" at top) and
      // a candidate for removal — history compression covers the same content later
      // without touching what the model is about to reason over.
      // Compress qualifying text blocks sequentially (usually exactly one).
      let changed = false;
      const out: typeof event.content = [];
      for (const block of event.content) {
        if (
          block.type !== 'text' ||
          block.text.length < MIN_CHARS ||
          block.text.includes('headroom_retrieve hash=') // already compressed
        ) {
          out.push(block);
          continue;
        }
        const compressed = await compressText(mcp, block.text, ctx.signal).catch((err) => {
          debugLog('compress failed:', err);
          return null;
        });
        if (compressed) {
          out.push({ type: 'text', text: compressed.text });
          compressions++;
          tokensSaved += compressed.saved;
          changed = true;
        } else {
          out.push(block);
        }
      }

      if (changed) return { content: out };
    } catch (err) {
      // Fail open: never block or corrupt a tool result.
      debugLog('tool_result handler error (passing through):', err);
      return;
    }
  });

  // ------------------------------------------------------------------
  // History compression: shrink stale toolResult messages in the outgoing
  // request payload. Non-destructive — session history keeps originals.
  // ------------------------------------------------------------------
  const cache: CompressionCache = new BoundedMap();
  let contextBusy = false;

  pi.on('context', async (event, ctx) => {
    if (CONTEXT_DISABLED || !enabled || !active || mcp.dead || contextBusy) return;
    try {
      contextBusy = true;

      // Don't spend latency on small contexts.
      const tokens = ctx.getContextUsage()?.tokens;
      if (typeof tokens === 'number' && tokens < MIN_CONTEXT_TOKENS) return;

      const lastCompressible = event.messages.length - 1 - KEEP_RECENT;
      let budget = batchSize;
      let changed = false;
      let freshCompressions = 0;
      let freshSaved = 0;

      for (let i = 0; i <= lastCompressible; i++) {
        const msg = event.messages[i] as AgentMessage & {
          toolName?: string;
          isError?: boolean;
          content?: unknown;
        };
        if (msg.role !== 'toolResult') continue;
        if (msg.isError) continue;
        // headroom_retrieve results are protected while fresh (the model asked for
        // the exact original), but once well past the recent window they are just
        // stale bulk — recompress them; they stay retrievable by definition.
        if (msg.toolName === RETRIEVE_TOOL && i > event.messages.length - 1 - KEEP_RECENT * 3) continue;
        if (!Array.isArray(msg.content)) continue;

        for (const block of msg.content as Array<{ type: string; text?: string }>) {
          if (block.type !== 'text' || typeof block.text !== 'string') continue;
          const text = block.text;
          if (text.length < MIN_CHARS) continue;
          if (text.includes('headroom_retrieve hash=')) continue;

          const key = sha256(text);
          let entry = cache.get(key);
          if (entry === undefined) {
            if (budget <= 0) continue; // pick it up on a later turn
            budget--;
            entry = await compressText(mcp, text, ctx.signal);
            cache.set(key, entry); // null = didn't pay off; never retry
            if (entry) {
              freshCompressions++;
              freshSaved += entry.saved;
            }
          }
          if (entry) {
            block.text = entry.text;
            changed = true;
          }
        }
      }

      if (freshCompressions > 0) {
        compressions += freshCompressions;
        tokensSaved += freshSaved;
      }
      if (changed) return { messages: event.messages };
    } catch (err) {
      // Fail open: send the context unmodified.
      debugLog('context handler error (passing through):', err);
      return;
    } finally {
      contextBusy = false;
    }
  });
}

/** Bounded FIFO map (oldest entries evicted first). */
class BoundedMap<V> {
  private map = new Map<string, V>();

  get(key: string): V | undefined {
    return this.map.get(key);
  }

  set(key: string, value: V): void {
    this.map.delete(key); // allow value updates without duplicating entries
    this.map.set(key, value);
    while (this.map.size > MAX_CACHE_ENTRIES) {
      const oldest = this.map.keys().next().value;
      if (oldest === undefined) break;
      this.map.delete(oldest);
    }
  }
}

/** Content hash → compression result (null = not worth it). */
type CompressionCache = BoundedMap<{ text: string; saved: number } | null>;

function sha256(text: string): string {
  return createHash('sha256').update(text).digest('hex');
}

/** Cheap token estimate; exact tokenization isn't worth a dependency here. */
function approxTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

/**
 * Replace a repeat `read` (same input, identical content) with a short marker.
 * The full text already exists earlier in history; the marker carries a CCR hash
 * so the model can always recover the exact bytes via headroom_retrieve.
 */
async function dedupRead(
  mcp: HeadroomMcp,
  readSeen: BoundedMap<{ hash: string } | null>,
  event: { input: Record<string, unknown>; content: Array<{ type: string; text?: string }> },
  signal?: AbortSignal
): Promise<{ content: Array<{ type: 'text'; text: string }> } | undefined> {
  // Replacing mixed content with a single text block would drop image blocks,
  // so only dedup reads that are pure text.
  if (!event.content.every((b) => b.type === 'text' && typeof b.text === 'string')) return undefined;
  const text = event.content.map((b) => b.text).join('\n');
  if (text.length < MIN_CHARS) return undefined;
  if (text.includes('headroom_retrieve hash=')) return undefined; // already a marker

  const key = sha256(JSON.stringify(event.input) + '\0' + text);
  const seen = readSeen.get(key);
  if (seen === undefined) {
    readSeen.set(key, null); // first read — pass through untouched
    return undefined;
  }

  // Duplicate. Ensure the original is in the CCR store (compress stores it).
  let hash = seen?.hash;
  if (!hash) {
    const result = await mcp
      .callTool('headroom_compress', { content: text }, COMPRESS_TIMEOUT_MS, signal)
      .catch((err) => {
        debugLog('read dedup store failed:', err);
        return null;
      });
    if (!result || typeof result.hash !== 'string') return undefined;
    hash = result.hash;
    readSeen.set(key, { hash });
  }

  return {
    content: [
      {
        type: 'text',
        text: `[headroom: unchanged since previous read. Full content via ${RETRIEVE_TOOL} hash=${hash}]`
      }
    ]
  };
}

/**
 * Compress one text block. Returns replacement text + tokens saved, or null when
 * compression didn't pay off. Throws on transport errors (timeout, dead server) —
 * callers must not cache those as permanent "not worth it" results.
 */
async function compressText(
  mcp: HeadroomMcp,
  text: string,
  signal?: AbortSignal
): Promise<{ text: string; saved: number } | null> {
  const result = await mcp.callTool('headroom_compress', { content: text }, COMPRESS_TIMEOUT_MS, signal);

  const savingsPct = Number(result.savings_percent ?? 0);
  const tokensSaved = Number(result.tokens_saved ?? 0);
  const hash = typeof result.hash === 'string' ? result.hash : null;
  if (result.compressed == null || !hash) return null;
  const compressed: string =
    typeof result.compressed === 'string' ? result.compressed : JSON.stringify(result.compressed);
  if (tokensSaved <= 0 || savingsPct < MIN_SAVINGS_PCT) return null;

  // The marker is part of what we send, so its cost must come out of the savings.
  // Carries no telemetry (before/after counts help the reader, not the model) —
  // only what the model needs: this is compressed, and the key to get it back.
  const marker = `\n[headroom: compressed. Full original via ${RETRIEVE_TOOL} hash=${hash}]`;
  const netSaved = tokensSaved - approxTokens(marker);
  if (netSaved <= 0) return null;
  if (compressed.length + marker.length >= text.length) return null;

  return { text: compressed + marker, saved: netSaved };
}

function registerRetrieveTool(pi: ExtensionAPI, mcp: HeadroomMcp) {
  pi.registerTool({
    name: RETRIEVE_TOOL,
    label: 'Headroom Retrieve',
    description:
      'Retrieve the full original content of a headroom-compressed tool output by hash. ' +
      "Use when output marked '[headroom: ... hash=XYZ]' lacks details you need.",
    promptSnippet: "Retrieve full originals of compressed tool outputs (see '[headroom: ... hash=XYZ]' markers)",
    parameters: Type.Object({
      hash: Type.String({
        description: "Hash from a compression marker, e.g. 'abc123' from hash=abc123"
      })
    }),
    async execute(_toolCallId, params, signal) {
      const result = await mcp.callTool(
        'headroom_retrieve',
        { hash: params.hash },
        COMPRESS_TIMEOUT_MS,
        signal ?? undefined
      );
      const original =
        (typeof result.original_content === 'string' && result.original_content) ||
        (typeof result.content === 'string' && result.content) ||
        JSON.stringify(result, null, 2);
      return { content: [{ type: 'text', text: original }], details: {} };
    }
  });
}
