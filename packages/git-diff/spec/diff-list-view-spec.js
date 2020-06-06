const path = require('path');
const fs = require('fs-plus');
const temp = require('temp');

describe('git-diff:toggle-diff-list', () => {
  let diffListView, editor;

  beforeEach(() => {
    const projectPath = temp.mkdirSync('git-diff-spec-');
    fs.copySync(path.join(__dirname, 'fixtures', 'working-dir'), projectPath);
    fs.moveSync(
      path.join(projectPath, 'git.git'),
      path.join(projectPath, '.git')
    );
    atom.project.setPaths([projectPath]);

    jasmine.attachToDOM(atom.workspace.getElement());

    waitsForPromise(() => atom.packages.activatePackage('git-diff'));

    waitsForPromise(() => atom.workspace.open('sample.js'));

    runs(() => {
      editor = atom.workspace.getActiveTextEditor();
      editor.setCursorBufferPosition([8, 30]);
      editor.insertText('a');
      atom.commands.dispatch(editor.getElement(), 'git-diff:toggle-diff-list');
    });

    waitsFor(() => {
      diffListView = document.querySelector('.diff-list-view');
      return diffListView && diffListView.querySelectorAll('li').length > 0;
    });
  });

  it('shows a list of all diff hunks', () => {
    diffListView = document.querySelector('.diff-list-view ol');
    expect(diffListView.textContent).toBe(
      'while (items.length > 0) {a-9,1 +9,1'
    );
  });

  it('moves the cursor to the selected hunk', () => {
    editor.setCursorBufferPosition([0, 0]);
    atom.commands.dispatch(
      document.querySelector('.diff-list-view'),
      'core:confirm'
    );
    expect(editor.getCursorBufferPosition()).toEqual([8, 4]);
  });
});
