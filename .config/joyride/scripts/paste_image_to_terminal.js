//@ts-check
// Requires Joyride to run on the UI host so the *local* clipboard is read:
//   "remote.extensionKind": { "betterthantomorrow.joyride": ["ui"] }
// macOS only (osascript). Remote: file is copied to /tmp on the remote via workspace.fs.
const vscode = require('vscode');
const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');

async function main() {
  const name = `vscode-clipboard-${Date.now()}.png`;
  const local = path.join(os.tmpdir(), name);
  try {
    await promisify(execFile)('osascript', [
      '-e', `set f to open for access POSIX file "${local}" with write permission`,
      '-e', 'write (the clipboard as «class PNGf») to f',
      '-e', 'close access f',
    ]);
  } catch {
    fs.rmSync(local, { force: true });
    return;
  }

  const terminal = vscode.window.activeTerminal;
  let target = local;
  const ws = vscode.workspace.workspaceFolders?.[0]?.uri;
  if (vscode.env.remoteName && ws) {
    target = `/tmp/${name}`;
    await vscode.workspace.fs.writeFile(ws.with({ path: target }), fs.readFileSync(local));
    fs.rmSync(local, { force: true });
  } else if (terminal) {
    const container = await containerOf(terminal);
    if (container) {
      target = `/tmp/${name}`;
      await promisify(execFile)('docker', ['cp', local, `${container}:${target}`]).catch(() => { target = local; });
    }
  }

  if (terminal) {
    terminal.sendText(target + ' ', false);
    terminal.show();
  }
}

exports.main = main;

main();

// Walk the terminal shell's process tree looking for a `docker exec/attach pi-...`.
/** @param {import('vscode').Terminal} terminal */
async function containerOf(terminal) {
  const pid = await terminal.processId;
  if (!pid) return null;
  try {
    const { stdout } = await promisify(execFile)('ps', ['-ax', '-o', 'pid=,ppid=,command=']);
    const procs = stdout.split('\n').flatMap((l) => {
      const m = l.trim().match(/^(\d+)\s+(\d+)\s+(.*)$/);
      return m ? [{ pid: +m[1], ppid: +m[2], cmd: m[3] }] : [];
    });
    const queue = [pid];
    while (queue.length) {
      const cur = queue.shift();
      for (const p of procs) {
        if (p.ppid !== cur) continue;
        const m = p.cmd.match(/docker\s+(?:exec|attach)\b.*?\b(pi-[\w.-]+)/);
        if (m) return m[1];
        queue.push(p.pid);
      }
    }
  } catch { }
  return null;
}
