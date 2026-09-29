import { CustomEditor, type ExtensionAPI } from '@earendil-works/pi-coding-agent';

export default function (pi: ExtensionAPI) {
  pi.registerFlag('auto-exit', {
    description: 'Exit after the agent finishes, including retries and queued follow-ups',
    type: 'boolean',
    default: false
  });

  pi.on('session_start', (_event, ctx) => {
    if (pi.getFlag('auto-exit') !== true || ctx.mode !== 'tui') return;
    // ponytail: prototype patch so it also hides editors set by other extensions (cursor.ts) regardless of load order
    CustomEditor.prototype.render = () => [];
    ctx.ui.setFooter(() => ({ render: () => [], invalidate() {} }));
  });

  pi.on('agent_settled', (_event, ctx) => {
    if (pi.getFlag('auto-exit') === true) ctx.shutdown();
  });
}
