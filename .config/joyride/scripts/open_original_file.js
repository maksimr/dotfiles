// https://github.com/microsoft/vscode/issues/234814
//@ts-check
const vscode = require('vscode');

/** git:// and gitlens:// uris carry the real path in the query as JSON */
function toFileUri(/**@type {vscode.Uri | undefined}*/ uri) {
  if (!uri) return undefined;
  if (uri.scheme === 'file') return uri;
  try {
    const path = JSON.parse(uri.query).path;
    if (path) return vscode.Uri.file(path);
  } catch { }
  return uri.fsPath ? vscode.Uri.file(uri.fsPath) : undefined;
}

async function main() {
  const editor = vscode.window.activeTextEditor;
  const input = vscode.window.tabGroups.activeTabGroup.activeTab?.input;
  // prefer the focused side of the diff, fall back to the modified (right) side
  const source = editor?.document.uri ?? (input instanceof vscode.TabInputTextDiff
    ? input.modified
    : input instanceof vscode.TabInputText ? input.uri : undefined);
  const uri = toFileUri(source);
  if (!uri) return;

  const shown = await vscode.window.showTextDocument(uri, { preview: false });
  if (editor) {
    shown.selection = editor.selection;
    shown.revealRange(editor.selection, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
  }
}

exports.main = main;

main();
