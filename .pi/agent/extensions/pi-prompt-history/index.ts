/**
 * Prompt History Extension
 *
 * Records every prompt you type interactively (including /commands and /skill:...
 * invocations) to ~/.pi/agent/typed-prompt-history.jsonl.
 *
 * Press Ctrl+R to open a searchable history dialog:
 * - Type to filter (case-insensitive substring match)
 * - Navigation/confirm/cancel follow the tui.select.* keybindings
 *   (rebindable in keybindings.json, e.g. ctrl+n/ctrl+p for down/up)
 */

import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { DynamicBorder, getAgentDir } from '@earendil-works/pi-coding-agent';
import { fuzzyFilter, Input, type SelectItem, SelectList, Spacer } from '@earendil-works/pi-tui';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

interface HistoryEntry {
  text: string;
  ts: number;
}

const HISTORY_FILE = join(getAgentDir(), 'typed-prompt-history.jsonl');
const MAX_ENTRIES = 1000;
const MAX_VISIBLE = 10;

async function loadHistory(): Promise<HistoryEntry[]> {
  try {
    const content = await readFile(HISTORY_FILE, 'utf-8');
    return content
      .split('\n')
      .filter((line) => line.trim().length > 0)
      .map((line) => JSON.parse(line) as HistoryEntry)
      .filter((e) => typeof e.text === 'string' && e.text.length > 0);
  } catch {
    return [];
  }
}

// Serialize writes so concurrent saves never interleave; best-effort, never throws
let writeQueue: Promise<void> = Promise.resolve();

function saveHistory(entries: HistoryEntry[]): void {
  const snapshot = entries.map((e) => JSON.stringify(e)).join('\n') + '\n';
  writeQueue = writeQueue.then(async () => {
    try {
      await mkdir(dirname(HISTORY_FILE), { recursive: true });
      await writeFile(HISTORY_FILE, snapshot, 'utf-8');
    } catch {
      // Best-effort persistence; never break input handling
    }
  });
}

function relativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const min = Math.floor(diff / 60_000);
  if (min < 1) return 'just now';
  if (min < 60) return `${min}m ago`;
  const hours = Math.floor(min / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export default function (pi: ExtensionAPI) {
  let history: HistoryEntry[] = [];

  // Load persisted history in the background; consumers await this before touching history
  const loaded = loadHistory().then((persisted) => {
    history = persisted;
  });

  // Record every interactively typed prompt (commands and skills included,
  // since the input event sees raw text before expansion).
  pi.on('input', async (event) => {
    if (event.source !== 'interactive') return { action: 'continue' };
    const text = event.text.trim();
    if (text.length > 0) {
      await loaded;
      // Shell-history style dedupe: drop older identical entry, append newest
      history = history.filter((e) => e.text !== text);
      history.push({ text, ts: Date.now() });
      if (history.length > MAX_ENTRIES) history = history.slice(-MAX_ENTRIES);
      saveHistory(history);
    }
    return { action: 'continue' };
  });

  pi.registerShortcut('ctrl+r', {
    description: 'Search prompt history',
    handler: async (ctx: ExtensionContext) => {
      if (ctx.mode !== 'tui' || !ctx.hasUI) return;
      await loaded;
      if (history.length === 0) {
        ctx.ui.notify('Prompt history is empty', 'info');
        return;
      }

      // Newest first
      const entries = [...history].reverse();

      const selected = await ctx.ui.custom<string | null>(
        (tui, theme, keybindings, done) => {
          let filtered: HistoryEntry[] = entries;

          const input = new Input();
          input.focused = true;

          const applyFilter = (): void => {
            const query = input.getValue().trim();
            filtered = query.length === 0 ? entries : fuzzyFilter(entries, query, (e) => e.text);
          };

          const makeItems = (): SelectItem[] =>
            filtered.map((e, i) => ({
              value: String(i),
              label: e.text.replace(/[\r\n]+/g, ' ⏎ '),
              description: relativeTime(e.ts)
            }));

          const makeList = (listItems: SelectItem[]): SelectList => {
            const list = new SelectList(listItems, Math.min(Math.max(listItems.length, 1), MAX_VISIBLE), {
              selectedPrefix: (text) => theme.fg('accent', text),
              selectedText: (text) => theme.fg('accent', text),
              description: (text) => theme.fg('muted', text),
              scrollInfo: (text) => theme.fg('dim', text),
              noMatch: (text) => theme.fg('warning', text)
            });
            list.onSelect = (item) => {
              const entry = filtered[Number(item.value)];
              done(entry ? entry.text : null);
            };
            list.onCancel = () => done(null);
            return list;
          };

          let selectList = makeList(makeItems());

          const spacer = new Spacer(1);
          const border = new DynamicBorder((str: string) => theme.fg('border', str));

          return {
            render(width: number) {
              return [
                ...border.render(width),
                ...input.render(width),
                ...spacer.render(width),
                ...selectList.render(width),
                ...border.render(width)
              ];
            },
            invalidate() {
              selectList.invalidate();
            },
            handleInput(data: string) {
              if (
                keybindings.matches(data, 'tui.select.up') ||
                keybindings.matches(data, 'tui.select.down') ||
                keybindings.matches(data, 'tui.select.pageUp') ||
                keybindings.matches(data, 'tui.select.pageDown') ||
                keybindings.matches(data, 'tui.select.confirm') ||
                keybindings.matches(data, 'tui.select.cancel')
              ) {
                selectList.handleInput(data);
              } else {
                const before = input.getValue();
                input.handleInput(data);
                if (input.getValue() !== before) {
                  applyFilter();
                  selectList = makeList(makeItems());
                }
              }
              tui.requestRender();
            }
          };
        },
        {
          overlay: true
        }
      );

      if (selected) {
        ctx.ui.setEditorText(selected);
      }
    }
  });
}
