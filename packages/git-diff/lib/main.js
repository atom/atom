'use babel';

import GitDiffView from './git-diff-view';
import DiffListView from './diff-list-view';

let diffListView = null;

export default {
  activate() {
    const watchedEditors = new WeakSet();

    atom.workspace.observeTextEditors((editor) => {
      if (watchedEditors.has(editor)) return;

      new GitDiffView(editor).start();
      atom.commands.add(
        atom.views.getView(editor),
        'git-diff:toggle-diff-list',
        () => {
          if (diffListView == null) diffListView = new DiffListView();
          diffListView.toggle();
        }
      );

      watchedEditors.add(editor);
      editor.onDidDestroy(() => watchedEditors.delete(editor));
    });
  },

  deactivate() {
    if (diffListView) diffListView.destroy();
    diffListView = null;
  },
};
