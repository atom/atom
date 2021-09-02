'use babel';

/* eslint-env jasmine */

import GoToLineView from '../lib/go-to-line-view';

describe('GoToLine', () => {
  let editor = null;
  let editorView = null;
  let goToLine = null;

  beforeEach(() => {
    waitsForPromise(() => {
      return atom.workspace.open('sample.js');
    });

    runs(() => {
      const workspaceElement = atom.views.getView(atom.workspace);
      workspaceElement.style.height = '200px';
      workspaceElement.style.width = '1000px';
      jasmine.attachToDOM(workspaceElement);
      editor = atom.workspace.getActiveTextEditor();
      editorView = atom.views.getView(editor);
      goToLine = GoToLineView.activate();
      editor.setCursorBufferPosition([1, 0]);
    });
  });

  describe('when go-to-line:toggle is triggered', () => {
    it('adds a modal panel', () => {
      expect(goToLine.panel.isVisible()).toBeFalsy();
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
    });
  });

  describe('when entering a line number', () => {
    it('only allows 0-9 and the colon character to be entered in the mini editor', () => {
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText('a');
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText('path/file.txt:56');
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText(':');
      expect(goToLine.miniEditor.getText()).toBe(':');
      goToLine.miniEditor.setText('');
      goToLine.miniEditor.insertText('4');
      expect(goToLine.miniEditor.getText()).toBe('4');
    });
  });

  describe('when typing line numbers (auto-navigation)', () => {
    it('automatically scrolls to the desired line', () => {
      goToLine.miniEditor.insertText('19');
      expect(editor.getCursorBufferPosition()).toEqual([18, 0]);
    });
  });

  describe('when typing line and column numbers (auto-navigation)', () => {
    it('automatically scrolls to the desired line and column', () => {
      goToLine.miniEditor.insertText('3:8');
      expect(editor.getCursorBufferPosition()).toEqual([2, 7]);
    });
  });

  describe('when entering a line number and column number', () => {
    it('moves the cursor to the column number of the line specified', () => {
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText('3:14');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(editor.getCursorBufferPosition()).toEqual([2, 13]);
    });

    it('centers the selected line', () => {
      goToLine.miniEditor.insertText('45:4');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      const rowsPerPage = editor.getRowsPerPage();
      const currentRow = editor.getCursorBufferPosition().row;
      expect(editor.getFirstVisibleScreenRow()).toBe(
        Math.ceil(currentRow - rowsPerPage / 2)
      );
      expect(editor.getLastVisibleScreenRow()).toBe(
        currentRow + Math.floor(rowsPerPage / 2)
      );
    });
  });

  describe('when entering a line number greater than the number of rows in the buffer', () => {
    it('moves the cursor position to the first character of the last line', () => {
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText('78');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([77, 0]);
    });
  });

  describe('when entering a column number greater than the number in the specified line', () => {
    it('moves the cursor position to the last character of the specified line', () => {
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      expect(goToLine.miniEditor.getText()).toBe('');
      goToLine.miniEditor.insertText('3:43');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([2, 39]);
    });
  });

  describe('when core:confirm is triggered', () => {
    describe('when a line number has been entered', () => {
      it('moves the cursor to the first character of the line', () => {
        goToLine.miniEditor.insertText('3');
        atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
        expect(editor.getCursorBufferPosition()).toEqual([2, 4]);
      });
    });

    describe('when the line number entered is nested within foldes', () => {
      it('unfolds all folds containing the given row', () => {
        expect(editor.indentationForBufferRow(9)).toEqual(3);
        editor.foldAll();
        expect(editor.screenRowForBufferRow(9)).toEqual(0);
        goToLine.miniEditor.insertText('10');
        atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
        expect(editor.getCursorBufferPosition()).toEqual([9, 6]);
      });
    });
  });

  describe('when no line number has been entered', () => {
    it('closes the view and does not update the cursor position', () => {
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
    });
  });

  describe('when no line number has been entered, but a column number has been entered', () => {
    it('navigates to the column of the current line', () => {
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      goToLine.miniEditor.insertText('4:1');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([3, 0]);
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      goToLine.miniEditor.insertText(':19');
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:confirm');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([3, 18]);
    });
  });

  describe('when core:cancel is triggered', () => {
    it('closes the view and does not update the cursor position', () => {
      atom.commands.dispatch(editorView, 'go-to-line:toggle');
      expect(goToLine.panel.isVisible()).toBeTruthy();
      atom.commands.dispatch(goToLine.miniEditor.element, 'core:cancel');
      expect(goToLine.panel.isVisible()).toBeFalsy();
      expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
    });
  });
});
