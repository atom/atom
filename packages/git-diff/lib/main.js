'use babel';

import { CompositeDisposable } from 'atom';
import GitDiffView from './git-diff-view';
import DiffListView from './diff-list-view';

let diffListView = null;
let diffViews = new Set();
let subscriptions = null;

export default {
  activate(state) {
    subscriptions = new CompositeDisposable();

    subscriptions.add(
      atom.workspace.observeTextEditors(editor => {
        const editorElement = atom.views.getView(editor);
        const diffView = new GitDiffView(editor, editorElement);

        diffViews.add(diffView);

        const listViewCommand = 'git-diff:toggle-diff-list';
        const editorSubs = new CompositeDisposable(
          atom.commands.add(editorElement, listViewCommand, () => {
            if (diffListView == null) diffListView = new DiffListView();

            diffListView.toggle();
          }),
          editor.onDidDestroy(() => {
            diffView.destroy();
            diffViews.delete(diffView);
            editorSubs.dispose();
            subscriptions.remove(editorSubs);
          })
        );

        subscriptions.add(editorSubs);
      })
    );
  },

  deactivate() {
    diffListView = null;

    for (const diffView of diffViews) diffView.destroy();

    diffViews.clear();

    subscriptions.dispose();
    subscriptions = null;
  }
};
