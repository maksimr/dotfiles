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

  let target = local;
  const ws = vscode.workspace.workspaceFolders?.[0]?.uri;
  if (vscode.env.remoteName && ws) {
    target = `/tmp/${name}`;
    await vscode.workspace.fs.writeFile(ws.with({ path: target }), fs.readFileSync(local));
    fs.rmSync(local, { force: true });
  }

  const terminal = vscode.window.activeTerminal;
  if (terminal) {
    terminal.sendText(target + ' ', false);
    terminal.show();
  }
}

exports.main = main;

main();
