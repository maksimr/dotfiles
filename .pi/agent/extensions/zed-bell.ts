import { basename } from 'node:path';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';

const SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const PI_ICON = 'π';
const SPINNER_INTERVAL_MS = 120;
const SEPARATOR = ' · ';

export default function (pi: ExtensionAPI) {
  let running = false;
  let frame = 0;
  let timer: NodeJS.Timeout | undefined;

  const render = (ctx: ExtensionContext) => {
    if (!ctx.hasUI) return;
    const parts = [
      running ? `${SPINNER[frame % SPINNER.length]} ${PI_ICON}` : PI_ICON,
      basename(ctx.cwd),
      running ? 'Working...' : 'Idle',
      pi.getSessionName()
    ];
    ctx.ui.setTitle(parts.filter(Boolean).join(SEPARATOR));
  };

  const stopTimer = () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  };

  const setRunning = (ctx: ExtensionContext, value: boolean) => {
    running = value;
    stopTimer();
    if (running && ctx.hasUI) {
      timer = setInterval(() => {
        frame++;
        render(ctx);
      }, SPINNER_INTERVAL_MS);
      timer.unref?.();
    }
    render(ctx);
  };

  pi.on('session_start', (_e, ctx) => render(ctx));
  pi.on('agent_start', (_e, ctx) => setRunning(ctx, true));
  pi.on('turn_end', (_e, ctx) => render(ctx));

  pi.on('agent_end', async (_e, ctx) => {
    setRunning(ctx, false);
    process.stdout.write('\x07');
  });

  pi.on('session_shutdown', () => stopTimer());
}
