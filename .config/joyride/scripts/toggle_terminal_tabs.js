//@ts-check
const vscode = require('vscode');

async function main() {
  const config = vscode.workspace.getConfiguration('terminal.integrated.tabs');
  const enabled = config.get('enabled');
  await config.update('enabled', !enabled, vscode.ConfigurationTarget.Global);
  await vscode.commands.executeCommand(
    enabled ? 'workbench.action.terminal.focus' : 'workbench.action.terminal.focusTabs'
  );
}

exports.main = main;

main();
