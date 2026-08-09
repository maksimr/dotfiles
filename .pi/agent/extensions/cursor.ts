/**
 * Hides the input editor's cursor when the input is not focused — either
 * because focus is elsewhere within pi, or because the terminal / tmux pane
 * itself lost focus
 *
 * Terminal focus is tracked via DECSET 1004 focus reporting, plus active-pane
 * polling inside tmux (where focus events are unreliable).
 */

import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { CustomEditor } from '@earendil-works/pi-coding-agent';
import { execFile } from 'node:child_process';

// The editor draws the cursor as reverse-video: "\x1b[7m<grapheme>\x1b[0m".
// Stripping that wrapping hides the cursor while keeping the character.
const CURSOR_PATTERN = /\x1b\[7m((?:(?!\x1b).)*)\x1b\[0m/;

// Terminal focus reporting (DECSET 1004). The terminal (and tmux with
// `set -g focus-events on`) sends these when focus is gained or lost.
const ENABLE_FOCUS_REPORTING = '\x1b[?1004h';
const DISABLE_FOCUS_REPORTING = '\x1b[?1004l';
const FOCUS_IN = '\x1b[I';
const FOCUS_OUT = '\x1b[O';

// Shared across module generations: /reload re-imports this module, but the
// handleTerminalInput wrapper installed on the TUI instance (and any running
// tmux poll timer) belongs to the previous generation. Keeping state on
// globalThis lets old closures and the freshly loaded module stay in sync.
interface SharedFocusState {
  terminalFocused: boolean;
  onChange?: () => void;
  tmuxPollTimer?: ReturnType<typeof setInterval>;
}
const state: SharedFocusState = ((globalThis as Record<string, any>).__piCursorFocusState ??= {
  terminalFocused: true
});

let activeEditor: CustomCursorEditor | undefined;

function setTerminalFocused(focused: boolean): void {
  if (focused === state.terminalFocused) return;
  state.terminalFocused = focused;
  state.onChange?.();
}

// Inside tmux, focus events (DECSET 1004) are only forwarded when
// `focus-events on` is set AND clients have reattached since, so they are
// unreliable. Poll the active-pane state directly instead.
const TMUX_PANE = process.env.TMUX_PANE;
const TMUX_POLL_INTERVAL_MS = 300;

function startTmuxFocusPolling(): void {
  if (!TMUX_PANE || state.tmuxPollTimer) return;
  state.tmuxPollTimer = setInterval(() => {
    execFile(
      'tmux',
      ['display-message', '-p', '-t', TMUX_PANE, '#{&&:#{pane_active},#{window_active}}'],
      (err, stdout) => {
        if (err) return;
        setTerminalFocused(stdout.trim() === '1');
      }
    );
  }, TMUX_POLL_INTERVAL_MS);
}

function stopTmuxFocusPolling(): void {
  if (state.tmuxPollTimer) {
    clearInterval(state.tmuxPollTimer);
    state.tmuxPollTimer = undefined;
  }
}

class CustomCursorEditor extends CustomEditor {
  /** Focused within pi AND the terminal/tmux pane itself is focused. */
  private isCursorActive(): boolean {
    return this.focused && state.terminalFocused;
  }

  /** Called when terminal focus changes; re-render with the new state. */
  onTerminalFocusChange(): void {
    this.tui.requestRender();
  }

  override render(width: number): string[] {
    const lines = super.render(width);
    if (this.isCursorActive()) return lines;
    // Hide the cursor entirely while the input is not focused
    let stripped = false;
    return lines.map((line) => {
      if (stripped) return line;
      const replaced = line.replace(CURSOR_PATTERN, '$1');
      if (replaced !== line) stripped = true;
      return replaced;
    });
  }
}

// In fullscreen tuiMode the alt-screen TUI registers its own input listener
// first and consumes FOCUS_IN/FOCUS_OUT before extension listeners run, so
// observe focus events upstream by wrapping the TUI's raw input entry point.
function observeTerminalFocus(tui: unknown): void {
  const t = tui as { __focusCursorPatched?: boolean; handleTerminalInput: (data: string) => void };
  if (t.__focusCursorPatched || typeof t.handleTerminalInput !== 'function') return;
  t.__focusCursorPatched = true;
  const orig = t.handleTerminalInput.bind(t);
  t.handleTerminalInput = (data: string) => {
    if (data.includes(FOCUS_IN) || data.includes(FOCUS_OUT)) {
      setTerminalFocused(data.lastIndexOf(FOCUS_IN) > data.lastIndexOf(FOCUS_OUT));
    }
    orig(data);
  };
}

export default function (pi: ExtensionAPI) {
  let unsubscribe: (() => void) | undefined;

  // Re-install on every session_start: pi resets custom editors and
  // terminal-input listeners on session switch / fork / reload.
  pi.on('session_start', async (_event, ctx) => {
    if (ctx.mode !== 'tui') return;

    // Point the shared focus-change hook at this module generation's editor
    state.onChange = () => activeEditor?.onTerminalFocusChange();

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      observeTerminalFocus(tui);
      activeEditor = new CustomCursorEditor(tui, theme, keybindings);
      return activeEditor;
    });

    process.stdout.write(ENABLE_FOCUS_REPORTING);

    // Focus state is tracked in observeTerminalFocus (runs before any
    // consumer); this listener only strips leftover sequences so they don't
    // reach the editor as input in main-screen mode.
    unsubscribe?.();
    unsubscribe = ctx.ui.onTerminalInput((data) => {
      if (!data.includes(FOCUS_IN) && !data.includes(FOCUS_OUT)) return undefined;
      return { data: data.replaceAll(FOCUS_IN, '').replaceAll(FOCUS_OUT, '') };
    });

    startTmuxFocusPolling();
  });

  pi.on('session_shutdown', async () => {
    stopTmuxFocusPolling();
    process.stdout.write(DISABLE_FOCUS_REPORTING);
  });
}
