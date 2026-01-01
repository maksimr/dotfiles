// @ts-check
const vscode = require('vscode');

const globalObj = /** @type {globalThis & { joyrideDisposables?: vscode.Disposable[] }} */ (globalThis);
globalObj.joyrideDisposables = globalObj.joyrideDisposables ?? [];
const joyrideDisposables = globalObj.joyrideDisposables;

exports.main = function() {
  // Clear any previously registered disposables
  while (joyrideDisposables.length > 0) {
    const disposable = joyrideDisposables.pop();
    disposable?.dispose();
  }

  preventJoyrideOutputTerminal(joyrideDisposables);
}

function preventJoyrideOutputTerminal(/**@type {vscode.Disposable[]}*/ disposables) {
  const closeJoyrideOutputTerminals = (/**@type {vscode.Terminal}*/ terminal) => {
    if (terminal.name === 'Joyride Output') {
      terminal.dispose();
    }
  }

  // Close any open "Joyride Output" terminals
  const terminals = vscode.window.terminals;
  for (const terminal of terminals) {
    closeJoyrideOutputTerminals(terminal);
  }

  disposables.push(
    // Register a disposable to close "Joyride Output" terminals when opened
    vscode.window.onDidOpenTerminal((terminal) => {
      closeJoyrideOutputTerminals(terminal);
    })
  );
}