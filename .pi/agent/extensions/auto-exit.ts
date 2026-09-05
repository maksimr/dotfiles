import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export default function (pi: ExtensionAPI) {
  pi.registerFlag('auto-exit', {
    description: 'Exit after the agent finishes, including retries and queued follow-ups',
    type: 'boolean',
    default: false
  });

  pi.on('agent_settled', (_event, ctx) => {
    if (pi.getFlag('auto-exit') === true) ctx.shutdown();
  });
}
