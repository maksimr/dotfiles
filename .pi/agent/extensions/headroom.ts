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
//   HEADROOM_PI_TOOLS             comma list of tool names to compress (default: "bash")
//                                 NOTE: do NOT add "read" — edit.oldText must match
//                                 file contents exactly; compressing reads breaks edits.
//   HEADROOM_PI_MIN_CHARS         min output size to compress (default: 2500)
//   HEADROOM_PI_MIN_SAVINGS_PCT   keep original unless savings >= this (default: 10)
//   HEADROOM_PI_TIMEOUT_MS        per-compression timeout (default: 20000)
//   HEADROOM_PI_DEBUG=1           log MCP server stderr
//   HEADROOM_PI_CONTEXT=0         disable history compression (context event)
//   HEADROOM_PI_MIN_CONTEXT_TOKENS  history compression kicks in at this context size (default: 10000)
//   HEADROOM_PI_KEEP_RECENT       never compress the last N history messages (default: 4)
//   HEADROOM_PI_MAX_PER_TURN      max new compressions per LLM call (default: 3)
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
  (process.env.HEADROOM_PI_TOOLS ?? 'bash')
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
  /** Invoked once, right after the server handshake completes. */
  onReady?: () => void;
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
          this.onReady?.();
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

  // Footer status: "headroom: on" when active, backend stats once tokens are saved,
  // e.g. "headroom: 18× −2.6k (5%) $0.0077".
  let compressions = 0;
  let tokensSaved = 0;
  let backendStats: { compressions: number; saved: number; pct: number; cost: number } | null =
    null;
  const updateStatus = (ctx: {
    ui: { setStatus(key: string, text?: string): void; theme: { fg(color: 'dim', text: string): string } };
  }) => {
    if (!enabled) return;
    const fmt = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`);
    const s = backendStats;
    const text =
      mcp.dead || !active
        ? 'headroom: off'
        : s
          ? `headroom: ${s.compressions}× −${fmt(s.saved)} (${s.pct}%) $${s.cost.toFixed(4)}`
          : compressions === 0
            ? 'headroom: on'
            : `headroom: ${compressions}× −${fmt(tokensSaved)}`;
    ctx.ui.setStatus('headroom', ctx.ui.theme.fg('dim', text));
  };

  // Refresh backend stats (session totals incl. sub-agents) and re-render status.
  let statsBusy = false;
  const refreshStats = async (ctx: Parameters<typeof updateStatus>[0]) => {
    if (statsBusy || mcp.dead) return;
    statsBusy = true;
    try {
      const raw = await mcp.callTool('headroom_stats', {}, 5_000);
      const combined = (raw.combined ?? raw) as Record<string, unknown>;
      backendStats = {
        compressions: Number(combined.total_compressions ?? 0),
        saved: Number(combined.total_tokens_saved ?? 0),
        pct: Number(combined.savings_percent ?? 0),
        cost: Number(combined.estimated_cost_saved_usd ?? 0)
      };
    } catch (err) {
      debugLog('stats refresh failed:', err);
    } finally {
      statsBusy = false;
      updateStatus(ctx);
    }
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
    // Fetch initial stats as soon as the MCP server comes up (it starts lazily,
    // so earlier session-window savings show without waiting for a compression).
    mcp.onReady = () => void refreshStats(ctx);
  });

  const SUBCOMMANDS = ['stats', 'on', 'off'] as const;
  pi.registerCommand('headroom', {
    description: 'Headroom compression. Usage: /headroom [stats|on|off]',
    getArgumentCompletions: (prefix) =>
      SUBCOMMANDS.filter((c) => c.startsWith(prefix.trim().toLowerCase())).map((c) => ({
        value: c,
        label: c
      })),
    handler: async (args, ctx) => {
      const sub = args.trim().toLowerCase();
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
        default: {
          const fmt = (n: number) => n.toLocaleString();
          ctx.ui.notify(
            [
              `headroom: ${mcp.dead ? 'server dead' : active ? 'on' : 'off'}`,
              `session: ${compressions} compressions, ~${fmt(tokensSaved)} tokens saved`,
              'usage: /headroom [stats|on|off]'
            ].join('\n'),
            'info'
          );
        }
      }
    }
  });

  pi.on('tool_result', async (event, ctx) => {
    try {
      if (!enabled || !active || mcp.dead) return;
      if (event.isError) return; // keep error output exact
      if (!COMPRESS_TOOLS.has(event.toolName)) return;
      if (event.toolName === RETRIEVE_TOOL) return;

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

      if (changed) {
        void refreshStats(ctx);
        return { content: out };
      }
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
  const cache = new CompressionCache();
  let contextBusy = false;

  pi.on('context', async (event, ctx) => {
    if (CONTEXT_DISABLED || !enabled || !active || mcp.dead || contextBusy) return;
    try {
      contextBusy = true;

      // Don't spend latency on small contexts.
      const tokens = ctx.getContextUsage()?.tokens;
      if (typeof tokens === 'number' && tokens < MIN_CONTEXT_TOKENS) return;

      const lastCompressible = event.messages.length - 1 - KEEP_RECENT;
      let budget = MAX_PER_TURN;
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
        if (msg.toolName === RETRIEVE_TOOL) continue; // model asked for the original
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
        void refreshStats(ctx);
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

/** Bounded FIFO cache: content hash → compression result (null = not worth it). */
class CompressionCache {
  private map = new Map<string, { text: string; saved: number } | null>();

  get(key: string): { text: string; saved: number } | null | undefined {
    return this.map.get(key);
  }

  set(key: string, value: { text: string; saved: number } | null): void {
    if (this.map.has(key)) return;
    this.map.set(key, value);
    while (this.map.size > MAX_CACHE_ENTRIES) {
      const oldest = this.map.keys().next().value;
      if (oldest === undefined) break;
      this.map.delete(oldest);
    }
  }
}

function sha256(text: string): string {
  return createHash('sha256').update(text).digest('hex');
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
  let compressed = result.compressed;
  if (compressed == null || !hash) return null;
  if (typeof compressed !== 'string') compressed = JSON.stringify(compressed);
  if (tokensSaved <= 0 || savingsPct < MIN_SAVINGS_PCT) return null;
  if ((compressed as string).length >= text.length) return null;

  return {
    text:
      compressed +
      `\n\n[headroom: output compressed, ${result.original_tokens}→${result.compressed_tokens} tokens` +
      ` (${savingsPct}% saved). Full original available via ${RETRIEVE_TOOL} hash=${hash}]`,
    saved: tokensSaved
  };
}

function registerRetrieveTool(pi: ExtensionAPI, mcp: HeadroomMcp) {
  pi.registerTool({
    name: RETRIEVE_TOOL,
    label: 'Headroom Retrieve',
    description:
      'Retrieve the full original content of a headroom-compressed tool output by hash. ' +
      "Use when compressed output (marked with '[headroom: ... hash=XYZ]') lacks details you need.",
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
