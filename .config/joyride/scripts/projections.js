//@ts-check
const vscode = require('vscode');
const { dirname, basename, join } = require('path');

async function main() {
  const uri = vscode.window.activeTextEditor?.document.uri;
  const file = uri?.path ?? '';
  const projections = await getConfiguration(uri);
  const candidates = await findRelatedFiles(file, projections);
  if (candidates.length) {
    return await showQuickPick(candidates);
  }
  return null;

  async function getConfiguration(/**@type {vscode.Uri | undefined}*/ file) {
    const userProjectionsJson = JSON.parse(JSON.stringify(vscode.workspace.getConfiguration('projections.json')));
    const vscodeProjections = Object.keys(userProjectionsJson).length ?
      userProjectionsJson :
      getDefaultConfiguration()
    if (!file) {
      return vscodeProjections;
    }

    try {
      const workspaceFolder = vscode.workspace.getWorkspaceFolder(file);
      const projectionsFilePath = join(workspaceFolder?.uri.path || '', '.projections.json');
      const workspaceProjections = JSON.parse((
        await vscode.workspace.fs.readFile(vscode.Uri.file(projectionsFilePath))
      ).toString());
      return {
        ...vscodeProjections,
        ...workspaceProjections
      };
    } catch { }
    return vscodeProjections;
  }

  function getDefaultConfiguration() {
    return ['js', 'ts', 'tsx'].reduce((acc, ext) => {
      return {
        ...acc,
        [`**/*.${ext}`]: { alternate: `{}.test.${ext}` },
        [`**/*.${ext}`]: { alternate: `{}.spec.${ext}` },
        [`**/*.test.${ext}`]: { alternate: `{}.${ext}` },
        [`**/*.spec.${ext}`]: { alternate: `{}.${ext}` },
      };
    }, {});
  }

  /**
   * @param {string} file 
   * @param {{ [pattern: string]: { "alternate"?: string | string[] } }} projections 
   */
  async function findRelatedFiles(file, projections) {
    const candidates = Array.from(Object.entries(projections).reduce((candidates, [pattern, { alternate }]) => {
      const patternMatch = match(file, pattern);
      if (alternate && patternMatch) {
        [alternate].flat(1).forEach((alternate) => {
          const candidate = expand(alternate, { match: patternMatch, file });
          candidates.add(candidate);
        });
      }
      return candidates;
    }, new Set())).map((path) => vscode.Uri.file(path));

    return (await Promise.allSettled(candidates.map(async (uri) => {
      await vscode.workspace.fs.stat(uri);
      return uri;
    })))
      .filter((it) => {
        return it.status === 'fulfilled';
      })
      .map((it) => it.value);
  }

  /**
   * @param {vscode.Uri[]} candidates 
   */
  async function showQuickPick(candidates) {
    const quickPickItems = candidates.map((uri) => {
      const relativePath = vscode.workspace.asRelativePath(uri);
      // VSCode doesn't support file type icon for the quick pick dialog
      // @see https://github.com/microsoft/vscode/issues/59826
      return {
        label: relativePath,
        resourceUri: uri
      };
    });
    if (quickPickItems.length === 1) {
      return onDidSelectItem(quickPickItems[0]);
    }
    return vscode.window.showQuickPick(quickPickItems).then(onDidSelectItem);
  }

  /**
   * @param {(vscode.QuickPickItem & { resourceUri: vscode.Uri }) | undefined} value 
   */
  async function onDidSelectItem(value) {
    if (value) {
      const uri = value.resourceUri;
      const document = await vscode.workspace.openTextDocument(uri);
      await vscode.window.showTextDocument(document);
      return uri;
    }
    return null;
  }

  /**
   * @param {string} file 
   * @param {string} pattern 
   */
  function match(file, pattern) {
    if (/^[^*{}]*\*[^*{}]*$/.test(pattern)) {
      pattern = pattern.replace('*', '**/*');
    } else if (/^[^*{}]*\*\*[^*{}]+\*[^*{}]*$/.test(pattern)) {
      pattern = pattern;
    } else {
      return '';
    }
    const [prefix, infix, suffix] = pattern.split(/\*+/);
    if (!file.startsWith(prefix) || !file.endsWith(suffix)) {
      return '';
    }
    const match = file.substring(prefix.length, file.length - suffix.length);
    if (infix === '/') {
      return match;
    }
    const clean = match.replace(infix, '/');
    return clean === match ? '' : clean;
  }

  function expand(
    /**@type {string}*/
    value,
    /**@type {{ match?: string, post_function?: (value: [string]) => string } & { [transform: string]: string }}*/
    expansions,
    /**@type { Record<string, (value: string, expansion: typeof expansions) => string> }*/
    transformations = {
      dot: (input) => input.replace(/\//g, '.'),
      underscore: (input) => input.replace(/\//g, '_'),
      backslash: (input) => input.replace(/\//g, '\\'),
      colons: (input) => input.replace(/\//g, '::'),
      hyphenate: (input) => input.replace(/_/g, '-'),
      blank: (input) => input.replace(/[_-]/g, ''),
      uppercase: (input) => input.toUpperCase(),
      camelcase: (input) => input.replace(/[_-](.)/, (_, c) => c.toUpperCase()),
      capitalize: (input) => input.charAt(0).toUpperCase() + input.slice(1),
      dirname: (input) => dirname(input),
      basename: (input) => basename(input),
      open: () => '{',
      close: () => '{',
      nothing: () => '',
      vim: (it) => it
    }
  ) {
    return value.replace(/{[^{}]*}/g, (pattern) => {
      const transforms = pattern.substring(1, pattern.length - 1).split('|').filter((it) => it);
      let value = expansions[transforms[0]] ?? expansions.match ?? '';
      for (const transform of transforms) {
        if (!transformations[transform]) {
          return '';
        }
        value = transformations[transform](value, expansions);
        if (value === '') {
          return '';
        }
      }
      if (expansions['post_function']) {
        value = expansions['post_function']([value]);
      }
      return value;
    });
  }
}

main();