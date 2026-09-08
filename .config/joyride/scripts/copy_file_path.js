//@ts-check
const vscode = require('vscode');

async function main() {
  const editor = vscode.window.activeTextEditor;
  if (!editor) return;
  const filePath = editor.document.uri.fsPath;
  const selection = editor.selection;
  const start = selection.start.line + 1;
  const end = selection.end.line + 1;
  const range = (selection.isEmpty) ? '' : (start === end ? `:${start}` : `:${start}-${end}`);
  await vscode.env.clipboard.writeText(filePath + range);
}

exports.main = main;

main();
