//@ts-check
const vscode = require('vscode');

async function main() {
  const editor = vscode.window.activeTextEditor;
  const terminal = vscode.window.activeTerminal;
  if (!editor || !terminal) return;
  const filePath = editor.document.uri.fsPath;
  const selection = editor.selection;
  const start = selection.start.line + 1;
  const end = selection.end.line + 1;
  const range = start === end ? `:${start}` : `:${start}-${end}`;
  terminal.sendText(filePath + range + ' ', false);
  terminal.show();
}

exports.main = main;

main();
