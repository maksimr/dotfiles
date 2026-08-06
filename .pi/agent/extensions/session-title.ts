import { basename } from 'node:path';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';

const SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const PI_ICON = 'π';
const SPINNER_INTERVAL_MS = 120;
const SEPARATOR = ' · ';
const WAITING_ICON = '⏸';
const PERMISSION_PROMPT_CHANNEL = 'permissions:ui_prompt';
const PERMISSION_DECISION_CHANNEL = 'permissions:decision';

export default function (pi: ExtensionAPI) {
  let running = false;
  let waiting = false;
  let frame = 0;
  let timer: NodeJS.Timeout | undefined;
  let lastCtx: ExtensionContext | undefined;

  const render = (ctx: ExtensionContext) => {
    lastCtx = ctx;
    if (!ctx.hasUI) return;
    const icon = waiting
      ? `${WAITING_ICON} ${PI_ICON}`
      : running
        ? `${SPINNER[frame % SPINNER.length]} ${PI_ICON}`
        : PI_ICON;
    const parts = [icon, basename(ctx.cwd), waiting ? 'waiting' : running ? 'working...' : 'idle', pi.getSessionName()];
    ctx.ui.setTitle(parts.filter(Boolean).join(SEPARATOR));
  };

  const stopTimer = () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  };

  const setRunning = (ctx: ExtensionContext, value: boolean) => {
    running = value;
    stopTimer();
    if (running && !waiting && ctx.hasUI) {
      timer = setInterval(() => {
        frame++;
        render(ctx);
      }, SPINNER_INTERVAL_MS);
      timer.unref?.();
    }
    render(ctx);
  };

  const setWaiting = (value: boolean) => {
    if (waiting === value || !lastCtx) return;
    waiting = value;
    setRunning(lastCtx, running);
  };

  function ringBell() {
    process.stdout.write('\x07');
  }

  pi.events.on(PERMISSION_PROMPT_CHANNEL, () => {
    setWaiting(true);
    ringBell();
  });
  pi.events.on(PERMISSION_DECISION_CHANNEL, () => setWaiting(false));

  pi.on('session_start', (_e, ctx) => render(ctx));
  pi.on('agent_start', (_e, ctx) => setRunning(ctx, true));
  pi.on('turn_end', (_e, ctx) => render(ctx));

  pi.on('agent_end', async (_e, ctx) => {
    waiting = false;
    setRunning(ctx, false);
    ringBell();
  });

  pi.on('session_shutdown', () => stopTimer());
}
