import { spawn } from 'node:child_process';
import { readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';

// Lock content: running | ok | failed. mtime = last change.
const LOCK = join(tmpdir(), 'pi-auto-update.lock');
const INTERVAL_MS = 3 * 60 * 60 * 1000;

function tryLock(): boolean {
  try {
    writeFileSync(LOCK, 'running', { flag: 'wx' });
    return true;
  } catch {
    try {
      if (Date.now() - statSync(LOCK).mtimeMs < INTERVAL_MS) return false;
    } catch {}
    rmSync(LOCK, { force: true });
    try {
      writeFileSync(LOCK, 'running', { flag: 'wx' });
      return true;
    } catch {
      return false;
    }
  }
}

const rtf = new Intl.RelativeTimeFormat('en', { style: 'narrow', numeric: 'auto' });
const fmt = (ms: number) => {
  const min = Math.round((ms - Date.now()) / 60_000);
  if (min > -60) return rtf.format(min, 'minute');
  if (min > -1440) return rtf.format(Math.round(min / 60), 'hour');
  return rtf.format(Math.round(min / 1440), 'day');
};

export default function (pi: ExtensionAPI) {
  let current: ExtensionContext | undefined;
  let timer: NodeJS.Timeout | undefined;
  const render = () => {
    try {
      const state = readFileSync(LOCK, 'utf8').trim();
      const time = fmt(statSync(LOCK).mtimeMs);
      const text =
        state === 'running' ? 'updating…' : state === 'failed' ? `update: failed` : `updated: ${time}`;
      current?.ui.setStatus('auto-update', current.ui.theme.fg('dim', text));
    } catch {} // no lock yet, or ctx stale after reload
  };

  pi.on('session_start', (event, ctx) => {
    // Interactive only: skip print mode, subagents.
    if (!ctx.hasUI) return;
    current = ctx;
    if (event.reason === 'startup' && tryLock()) {
      // `--all` = `pi update` + `pi update --extensions`. Child writes the result, so it survives pi exiting first.
      const script = '"$0" "$1" update --all && echo ok > "$2" || echo failed > "$2"';
      const child = spawn('/bin/sh', ['-c', script, process.execPath, process.argv[1], LOCK], {
        detached: true,
        stdio: 'ignore'
      });
      child.on('exit', render);
      child.unref();
    }
    render();
    clearInterval(timer);
    timer = setInterval(render, 60_000); // keep relative time fresh
    timer.unref();
  });

  pi.on('session_shutdown', () => clearInterval(timer));
}
