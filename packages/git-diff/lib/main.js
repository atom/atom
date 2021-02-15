'use babel';

import { CompositeDisposable } from 'atom';
import GitDiffView from './git-diff-view';
import DiffListView from './diff-list-view';

let diffListView = null;
let diffViews = null;
let subscriptions = null;

export default {
  activate(state) {
    subscriptions = new CompositeDisposable();
    diffViews = new Set();

    subscriptions.add(
      atom.workspace.observeTextEditors(editor => {
        const editorElm = atom.views.getView(editor);
        const diffView = new GitDiffView(editor);

        diffViews.add(diffView);

        let editorSubs;
        const command = 'git-diff:toggle-diff-list';
        subscriptions.add(
          (editorSubs = new CompositeDisposable(
            atom.commands.add(editorElm, command, () => {
              if (diffListView == null) diffListView = new DiffListView();
              diffListView.toggle();
            }),
            editor.onDidDestroy(() => {
              diffView.destroy();
              diffViews.delete(diffView);
              editorSubs.dispose();
              subscriptions.remove(editorSubs);
            })
          ))
        );
      })
    );
  },

  deactivate() {
    diffListView = null;

    for (const v of diffViews) v.destroy();
    diffViews = null;

    subscriptions.dispose();
    subscriptions = null;
  }
};
