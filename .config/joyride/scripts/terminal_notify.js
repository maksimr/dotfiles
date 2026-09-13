// Watch terminal output for kitty OSC 99 desktop-notification sequences
// and forward them as OS notifications.
// Run via Joyride: Run User Script -> osc99_notify.js
// Requires VS Code shell integration (data is only visible during shell executions).
const vscode = require("vscode");
const cp = require("child_process");
const net = require("net");
const os = require("os");
const fs = require("fs");
const path = require("path");

// OSC 99 ; metadata ; payload  terminated by BEL or ST (ESC \)
const OSC99_RE = /\x1b\]99;([^;\x07\x1b]*);([^\x07\x1b]*)(?:\x07|\x1b\\)/g;

function metaMap(metadata) {
  const m = {};
  for (const kv of metadata.split(":")) {
    const [k, v] = kv.split("=");
    m[k] = v;
  }
  return m;
}

// https://github.com/julienXX/terminal-notifier - downloaded on first use.
const TN_VERSION = "3.1.0";
const TN_URL = `https://github.com/julienXX/terminal-notifier/releases/download/${TN_VERSION}/terminal-notifier-${TN_VERSION}.zip`;
// ~/Applications: LaunchServices only resolves the bundle id (and so the
// Notifications permission) for apps living in /Applications or ~/Applications.
const TN_DIR = path.join(os.homedir(), "Applications");
const TN_APP = path.join(TN_DIR, "terminal-notifier.app");
const TN_BIN = path.join(TN_APP, "Contents/MacOS/terminal-notifier");

// The notification icon always comes from the sending bundle, so give the copy
// VS Code's icon and its own bundle id (which is what earns it a separate icon).
function brandWithVscodeIcon() {
  const resources = path.dirname(vscode.env.appRoot); // <app>.app/Contents/Resources
  const icns = fs.readdirSync(resources).find((f) => f.endsWith(".icns"));
  if (!icns) return;
  fs.copyFileSync(path.join(resources, icns), path.join(TN_APP, "Contents/Resources/Terminal.icns"));
  const plist = path.join(TN_APP, "Contents/Info.plist");
  for (const set of [
    "Set :CFBundleIdentifier fr.julienxx.oss.terminal-notifier.vscode",
    `Set :CFBundleName ${vscode.env.appName}`,
  ]) cp.execFileSync("/usr/libexec/PlistBuddy", ["-c", set, plist]);
  try { // editing the bundle invalidates its signature
    cp.execFileSync("codesign", ["--force", "--sign", "-", TN_APP]);
  } catch (_) { }
  fs.utimesSync(TN_APP, new Date(), new Date()); // nudge the LaunchServices icon cache
}

/** @type {Promise<string>|undefined} */
let tnInstall;

function terminalNotifier() {
  if (fs.existsSync(TN_BIN)) return Promise.resolve(TN_BIN);
  tnInstall ??= vscode.window.withProgress(
    { location: vscode.ProgressLocation.Notification, title: `Downloading terminal-notifier ${TN_VERSION}` },
    async (progress) => {
      const res = await fetch(TN_URL);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const total = Number(res.headers.get("content-length")) || 0;
      const chunks = [];
      for await (const chunk of res.body) {
        chunks.push(chunk);
        if (total) progress.report({ increment: (chunk.length / total) * 100 });
      }
      const zip = path.join(os.tmpdir(), `terminal-notifier-${TN_VERSION}.zip`);
      fs.mkdirSync(TN_DIR, { recursive: true });
      fs.writeFileSync(zip, Buffer.concat(chunks));
      cp.execFileSync("unzip", ["-oq", zip, "terminal-notifier.app/*", "-d", TN_DIR]);
      fs.rmSync(zip, { force: true });
      // not notarized: Gatekeeper kills the first run while quarantined
      cp.execFileSync("xattr", ["-dr", "com.apple.quarantine", TN_APP]);
      brandWithVscodeIcon();
      // macOS only asks for permission when something is actually posted
      cp.execFile(TN_BIN, ["-title", "Terminal", "-message", "Notifications enabled"], () => { });
      return TN_BIN;
    }
  ).then(undefined, (err) => {
    tnInstall = undefined; // retry on next notification
    throw err;
  });
  return tnInstall;
}

let warned = false;
function warnOnce() {
  if (warned) return;
  warned = true;
  vscode.window.showWarningMessage(
    "terminal-notifier is not allowed to post notifications. Enable it in System Settings > Notifications > terminal-notifier."
  );
}

// Clicking a terminal-notifier banner relaunches *its* bundle to run -execute,
// so the click has to travel back here over a socket to reach the terminal.
const SOCK = path.join(os.tmpdir(), `terminal-notify-${process.pid}.sock`);
/** @type {Map<string, import('vscode').Terminal>} */
const clickTargets = new Map();
let clickId = 0;

function registerClickTarget(terminal) {
  const id = String(++clickId);
  clickTargets.set(id, terminal);
  if (clickTargets.size > 50) clickTargets.delete(clickTargets.keys().next().value);
  return id;
}

function clickServer() {
  fs.rmSync(SOCK, { force: true });
  const server = net.createServer((conn) => {
    let id = "";
    conn.on("data", (d) => (id += d));
    conn.on("end", () => clickTargets.get(id.trim())?.show());
  });
  server.listen(SOCK);
  return { dispose: () => { server.close(); fs.rmSync(SOCK, { force: true }); } };
}

/** @type {string|undefined} */
let bundleId;
function vscodeBundleId() {
  if (bundleId !== undefined) return bundleId;
  try {
    const plist = path.join(path.dirname(path.dirname(vscode.env.appRoot)), "Info.plist");
    bundleId = cp.execFileSync("/usr/libexec/PlistBuddy", ["-c", "Print :CFBundleIdentifier", plist])
      .toString().trim();
  } catch (_) {
    bundleId = ""; // unknown bundle: skip -activate, -execute still works
  }
  return bundleId;
}

function notify(title, body, terminal) {
  // skip only when VS Code is focused and this terminal is the visible one
  if (vscode.window.state.focused && vscode.window.activeTerminal === terminal) return;
  switch (os.platform()) {
    case "linux": {
      // -A makes the banner clickable and prints the action name on click
      const p = cp.spawn("notify-send", ["-A", "default=Show", title, body]);
      p.stdout.on("data", () => terminal?.show());
      break;
    }
    case "darwin": {
      const id = registerClickTarget(terminal);
      const activate = vscodeBundleId() ? ["-activate", vscodeBundleId()] : [];
      terminalNotifier().then(
        (bin) => cp.execFile(bin, [
          "-title", title, "-message", body, ...activate,
          "-execute", `printf %s '${id}' | nc -U '${SOCK}'`,
        ], (err) => {
          if (!err) return;
          // 3 = notifications not authorized, one-time until the user allows it
          if (/** @type {any} */(err).code === 3) warnOnce();
        }),
      );
      break;
    }
    default: // incl. win32: VS Code toast
      vscode.window.showInformationMessage(`${title}: ${body}`, "Show")
        .then((pick) => pick && terminal?.show());
  }
}

// kitty sends title (p=title) and body (p=body) as separate sequences,
// grouped by i=<id>. Accumulate per id, fire on done (d absent or d=1).
const pending = new Map();

function handleSeq(metadata, payload, terminal) {
  const m = metaMap(metadata);
  const id = m.i ?? "0";
  const text = m.e === "1" ? Buffer.from(payload, "base64").toString("utf8") : payload;
  const acc = pending.get(id) ?? {};
  acc[m.p === "body" ? "body" : "title"] = text;
  pending.set(id, acc);
  if ((m.d ?? "1") !== "0") {
    pending.delete(id);
    if (acc.title && !acc.body) {
      acc.body = acc.title;
      acc.title = undefined;
    }
    const title = acc.title ?? vscode.workspace.name ?? "Terminal";
    notify(title, acc.body ?? "", terminal);
  }
}

function makeScanner(terminal) {
  let buf = "";
  return (chunk) => {
    buf += chunk;
    if (buf.length > 8192) buf = buf.slice(-8192); // seqs can split across chunks
    OSC99_RE.lastIndex = 0;
    let lastEnd = 0;
    let match;
    while ((match = OSC99_RE.exec(buf))) {
      handleSeq(match[1], match[2], terminal);
      lastEnd = OSC99_RE.lastIndex;
    }
    buf = buf.slice(lastEnd);
  };
}

// Terminals revived after a VS Code restart never get shell integration
// re-attached (microsoft/vscode#208645), so shell execution events never fire
// and OSC 99 is invisible in them. Only relaunch command profiles running
// exec pi or exec pix; leave ordinary interactive shells alone.
async function fixRevivedTerminals() {
  const dead = vscode.window.terminals.filter((t) => {
    if (t.shellIntegration || t.exitStatus || !("shellArgs" in t.creationOptions)) return false;
    const args = t.creationOptions.shellArgs;
    // ponytail: only array-form, direct exec profiles; extend for other launch forms.
    if (!Array.isArray(args)) return false;
    const commandFlag = args.findIndex((arg) => /^-[il]*c[il]*$/.test(arg));
    return commandFlag !== -1 && /^\s*exec\s+pix?(?:\s|$)/.test(args[commandFlag + 1] ?? "");
  });
  if (!dead.length) return;
  const active = vscode.window.activeTerminal;
  for (const t of dead) {
    t.show(true); // relaunch acts on the active terminal
    await vscode.commands.executeCommand("workbench.action.terminal.relaunch");
  }
  active?.show(true);
}

exports.main = function(/**@type {import('vscode').Disposable[]}*/ disposables) {
  if (os.platform() === "darwin") {
    terminalNotifier().catch(() => { });
    disposables.push(clickServer());
  }
  fixRevivedTerminals();
  disposables.push(
    vscode.window.onDidStartTerminalShellExecution(async (e) => {
      const scan = makeScanner(e.terminal);
      try {
        for await (const chunk of e.execution.read()) scan(chunk);
      } catch (_) { }
    })
  );
};
