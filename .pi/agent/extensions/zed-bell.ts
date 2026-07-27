import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export default function (pi: ExtensionAPI) {
  pi.on('agent_end', async () => {
    process.stdout.write('\x07');
  });
}
