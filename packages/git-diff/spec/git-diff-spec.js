const path = require('path');
const fs = require('fs-plus');
const temp = require('temp');

describe('GitDiff package', () => {
  let editor, editorElement, projectPath;

  beforeEach(() => {
    spyOn(window, 'setImmediate').andCallFake(fn => fn());

    projectPath = temp.mkdirSync('git-diff-spec-');
    const otherPath = temp.mkdirSync('some-other-path-');

    fs.copySync(path.join(__dirname, 'fixtures', 'working-dir'), projectPath);
    fs.moveSync(
      path.join(projectPath, 'git.git'),
      path.join(projectPath, '.git')
    );
    atom.project.setPaths([otherPath, projectPath]);

    jasmine.attachToDOM(atom.workspace.getElement());

    waitsForPromise(() =>
      atom.workspace.open(path.join(projectPath, 'sample.js'))
    );

    runs(() => {
      editor = atom.workspace.getActiveTextEditor();
      editorElement = editor.getElement();
    });

    waitsForPromise(() => atom.packages.activatePackage('git-diff'));
  });

  describe('when the editor has modified lines', () => {
    it('highlights the modified lines', () => {
      expect(editorElement.querySelectorAll('.git-line-modified').length).toBe(
        0
      );
      editor.insertText('a');
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(editorElement.querySelectorAll('.git-line-modified').length).toBe(
        1
      );
      expect(editorElement.querySelector('.git-line-modified')).toHaveData(
        'buffer-row',
        0
      );
    });
  });

  describe('when the editor has added lines', () => {
    it('highlights the added lines', () => {
      expect(editorElement.querySelectorAll('.git-line-added').length).toBe(0);
      editor.moveToEndOfLine();
      editor.insertNewline();
      editor.insertText('a');
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(editorElement.querySelectorAll('.git-line-added').length).toBe(1);
      expect(editorElement.querySelector('.git-line-added')).toHaveData(
        'buffer-row',
        1
      );
    });
  });

  describe('when the editor has removed lines', () => {
    it('highlights the line preceeding the deleted lines', () => {
      expect(editorElement.querySelectorAll('.git-line-added').length).toBe(0);
      editor.setCursorBufferPosition([5]);
      editor.deleteLine();
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(editorElement.querySelectorAll('.git-line-removed').length).toBe(
        1
      );
      expect(editorElement.querySelector('.git-line-removed')).toHaveData(
        'buffer-row',
        4
      );
    });
  });

  describe('when the editor has removed the first line', () => {
    it('highlights the line preceeding the deleted lines', () => {
      expect(editorElement.querySelectorAll('.git-line-added').length).toBe(0);
      editor.setCursorBufferPosition([0, 0]);
      editor.deleteLine();
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(
        editorElement.querySelectorAll('.git-previous-line-removed').length
      ).toBe(1);
      expect(
        editorElement.querySelector('.git-previous-line-removed')
      ).toHaveData('buffer-row', 0);
    });
  });

  describe('when a modified line is restored to the HEAD version contents', () => {
    it('removes the diff highlight', () => {
      expect(editorElement.querySelectorAll('.git-line-modified').length).toBe(
        0
      );
      editor.insertText('a');
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(editorElement.querySelectorAll('.git-line-modified').length).toBe(
        1
      );
      editor.backspace();
      advanceClock(editor.getBuffer().stoppedChangingDelay);
      expect(editorElement.querySelectorAll('.git-line-modified').length).toBe(
        0
      );
    });
  });

  describe('when a modified file is opened', () => {
    it('highlights the changed lines', () => {
      fs.writeFileSync(
        path.join(projectPath, 'sample.txt'),
        'Some different text.'
      );
      let nextTick = false;

      waitsForPromise(() =>
        atom.workspace.open(path.join(projectPath, 'sample.txt'))
      );

      runs(() => {
        editorElement = atom.workspace.getActiveTextEditor().getElement();
      });

      setImmediate(() => {
        nextTick = true;
      });

      waitsFor(() => nextTick);

      runs(() => {
        expect(
          editorElement.querySelectorAll('.git-line-modified').length
        ).toBe(1);
        expect(editorElement.querySelector('.git-line-modified')).toHaveData(
          'buffer-row',
          0
        );
      });
    });
  });

  describe('when the project paths change', () => {
    it("doesn't try to use the destroyed git repository", () => {
      editor.deleteLine();
      atom.project.setPaths([temp.mkdirSync('no-repository')]);
      advanceClock(editor.getBuffer().stoppedChangingDelay);
    });
  });

  describe('move-to-next-diff/move-to-previous-diff events', () => {
    it('moves the cursor to first character of the next/previous diff line', () => {
      editor.insertText('a');
      editor.setCursorBufferPosition([5]);
      editor.deleteLine();
      advanceClock(editor.getBuffer().stoppedChangingDelay);

      editor.setCursorBufferPosition([0]);
      atom.commands.dispatch(editorElement, 'git-diff:move-to-next-diff');
      expect(editor.getCursorBufferPosition()).toEqual([4, 4]);

      atom.commands.dispatch(editorElement, 'git-diff:move-to-previous-diff');
      expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
    });

    it('wraps around to the first/last diff in the file', () => {
      editor.insertText('a');
      editor.setCursorBufferPosition([5]);
      editor.deleteLine();
      advanceClock(editor.getBuffer().stoppedChangingDelay);

      editor.setCursorBufferPosition([0]);
      atom.commands.dispatch(editorElement, 'git-diff:move-to-next-diff');
      expect(editor.getCursorBufferPosition()).toEqual([4, 4]);

      atom.commands.dispatch(editorElement, 'git-diff:move-to-next-diff');
      expect(editor.getCursorBufferPosition()).toEqual([0, 0]);

      atom.commands.dispatch(editorElement, 'git-diff:move-to-previous-diff');
      expect(editor.getCursorBufferPosition()).toEqual([4, 4]);
    });

    describe('when the wrapAroundOnMoveToDiff config option is false', () => {
      beforeEach(() =>
        atom.config.set('git-diff.wrapAroundOnMoveToDiff', false)
      );

      it('does not wraps around to the first/last diff in the file', () => {
        editor.insertText('a');
        editor.setCursorBufferPosition([5]);
        editor.deleteLine();
        advanceClock(editor.getBuffer().stoppedChangingDelay);

        editor.setCursorBufferPosition([0]);
        atom.commands.dispatch(editorElement, 'git-diff:move-to-next-diff');
        expect(editor.getCursorBufferPosition()).toEqual([4, 4]);

        atom.commands.dispatch(editorElement, 'git-diff:move-to-next-diff');
        expect(editor.getCursorBufferPosition()).toEqual([4, 4]);

        atom.commands.dispatch(editorElement, 'git-diff:move-to-previous-diff');
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);

        atom.commands.dispatch(editorElement, 'git-diff:move-to-previous-diff');
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });
    });
  });

  describe('when the showIconsInEditorGutter config option is true', () => {
    beforeEach(() => {
      atom.config.set('git-diff.showIconsInEditorGutter', true);
    });

    it('the gutter has a git-diff-icon class', () =>
      expect(editorElement.querySelector('.gutter')).toHaveClass(
        'git-diff-icon'
      ));

    it('keeps the git-diff-icon class when editor.showLineNumbers is toggled', () => {
      atom.config.set('editor.showLineNumbers', false);
      expect(editorElement.querySelector('.gutter')).not.toHaveClass(
        'git-diff-icon'
      );

      atom.config.set('editor.showLineNumbers', true);
      expect(editorElement.querySelector('.gutter')).toHaveClass(
        'git-diff-icon'
      );
    });

    it('removes the git-diff-icon class when the showIconsInEditorGutter config option set to false', () => {
      atom.config.set('git-diff.showIconsInEditorGutter', false);
      expect(editorElement.querySelector('.gutter')).not.toHaveClass(
        'git-diff-icon'
      );
    });
  });
});
