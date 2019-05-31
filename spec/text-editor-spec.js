const fs = require('fs');
const path = require('path');
const temp = require('temp').track();
const dedent = require('dedent');
const { clipboard } = require('electron');
const TextEditor = require('../src/text-editor');
const TextBuffer = require('text-buffer');
const TextMateLanguageMode = require('../src/text-mate-language-mode');
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode');

describe('TextEditor', () => {
  let buffer, editor, lineLengths;

  beforeEach(async () => {
    editor = await atom.workspace.open('sample.js');
    buffer = editor.buffer;
    editor.update({ autoIndent: false });
    lineLengths = buffer.getLines().map(line => line.length);
    await atom.packages.activatePackage('language-javascript');
  });

  it('generates unique ids for each editor', async () => {
    // Deserialized editors are initialized with the serialized id. We can
    // initialize an editor with what we expect to be the next id:
    const deserialized = new TextEditor({ id: editor.id + 1 });
    expect(deserialized.id).toEqual(editor.id + 1);

    // The id generator should skip the id used up by the deserialized one:
    const fresh = new TextEditor();
    expect(fresh.id).toNotEqual(deserialized.id);
  });

  describe('when the editor is deserialized', () => {
    it('restores selections and folds based on markers in the buffer', async () => {
      editor.setSelectedBufferRange([[1, 2], [3, 4]]);
      editor.addSelectionForBufferRange([[5, 6], [7, 5]], { reversed: true });
      editor.foldBufferRow(4);
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();

      const buffer2 = await TextBuffer.deserialize(editor.buffer.serialize());
      const editor2 = TextEditor.deserialize(editor.serialize(), {
        assert: atom.assert,
        textEditors: atom.textEditors,
        project: {
          bufferForIdSync() {
            return buffer2;
          }
        }
      });

      expect(editor2.id).toBe(editor.id);
      expect(editor2.getBuffer().getPath()).toBe(editor.getBuffer().getPath());
      expect(editor2.getSelectedBufferRanges()).toEqual([
        [[1, 2], [3, 4]],
        [[5, 6], [7, 5]]
      ]);
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy();
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy();
      editor2.destroy();
    });

    it("restores the editor's layout configuration", async () => {
      editor.update({
        softTabs: true,
        atomicSoftTabs: false,
        tabLength: 12,
        softWrapped: true,
        softWrapAtPreferredLineLength: true,
        softWrapHangingIndentLength: 8,
        invisibles: { space: 'S' },
        showInvisibles: true,
        editorWidthInChars: 120
      });

      // Force buffer and display layer to be deserialized as well, rather than
      // reusing the same buffer instance
      const buffer2 = await TextBuffer.deserialize(editor.buffer.serialize());
      const editor2 = TextEditor.deserialize(editor.serialize(), {
        assert: atom.assert,
        textEditors: atom.textEditors,
        project: {
          bufferForIdSync() {
            return buffer2;
          }
        }
      });

      expect(editor2.getSoftTabs()).toBe(editor.getSoftTabs());
      expect(editor2.hasAtomicSoftTabs()).toBe(editor.hasAtomicSoftTabs());
      expect(editor2.getTabLength()).toBe(editor.getTabLength());
      expect(editor2.getSoftWrapColumn()).toBe(editor.getSoftWrapColumn());
      expect(editor2.getSoftWrapHangingIndentLength()).toBe(
        editor.getSoftWrapHangingIndentLength()
      );
      expect(editor2.getInvisibles()).toEqual(editor.getInvisibles());
      expect(editor2.getEditorWidthInChars()).toBe(
        editor.getEditorWidthInChars()
      );
      expect(editor2.displayLayer.tabLength).toBe(editor2.getTabLength());
      expect(editor2.displayLayer.softWrapColumn).toBe(
        editor2.getSoftWrapColumn()
      );
    });

    it('ignores buffers with retired IDs', () => {
      const editor2 = TextEditor.deserialize(editor.serialize(), {
        assert: atom.assert,
        textEditors: atom.textEditors,
        project: {
          bufferForIdSync() {
            return null;
          }
        }
      });

      expect(editor2).toBeNull();
    });
  });

  describe('.copy()', () => {
    it('returns a different editor with the same initial state', () => {
      expect(editor.getAutoHeight()).toBeFalsy();
      expect(editor.getAutoWidth()).toBeFalsy();
      expect(editor.getShowCursorOnSelection()).toBeTruthy();

      const element = editor.getElement();
      element.setHeight(100);
      element.setWidth(100);
      jasmine.attachToDOM(element);

      editor.update({ showCursorOnSelection: false });
      editor.setSelectedBufferRange([[1, 2], [3, 4]]);
      editor.addSelectionForBufferRange([[5, 6], [7, 8]], { reversed: true });
      editor.setScrollTopRow(3);
      expect(editor.getScrollTopRow()).toBe(3);
      editor.setScrollLeftColumn(4);
      expect(editor.getScrollLeftColumn()).toBe(4);
      editor.foldBufferRow(4);
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();

      const editor2 = editor.copy();
      const element2 = editor2.getElement();
      element2.setHeight(100);
      element2.setWidth(100);
      jasmine.attachToDOM(element2);
      expect(editor2.id).not.toBe(editor.id);
      expect(editor2.getSelectedBufferRanges()).toEqual(
        editor.getSelectedBufferRanges()
      );
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy();
      expect(editor2.getScrollTopRow()).toBe(3);
      expect(editor2.getScrollLeftColumn()).toBe(4);
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy();
      expect(editor2.getAutoWidth()).toBe(false);
      expect(editor2.getAutoHeight()).toBe(false);
      expect(editor2.getShowCursorOnSelection()).toBeFalsy();

      // editor2 can now diverge from its origin edit session
      editor2.getLastSelection().setBufferRange([[2, 1], [4, 3]]);
      expect(editor2.getSelectedBufferRanges()).not.toEqual(
        editor.getSelectedBufferRanges()
      );
      editor2.unfoldBufferRow(4);
      expect(editor2.isFoldedAtBufferRow(4)).not.toBe(
        editor.isFoldedAtBufferRow(4)
      );
    });
  });

  describe('.update()', () => {
    it('updates the editor with the supplied config parameters', () => {
      let changeSpy;
      const { element } = editor; // force element initialization
      element.setUpdatedSynchronously(false);
      editor.update({ showInvisibles: true });
      editor.onDidChange((changeSpy = jasmine.createSpy('onDidChange')));

      const returnedPromise = editor.update({
        tabLength: 6,
        softTabs: false,
        softWrapped: true,
        editorWidthInChars: 40,
        showInvisibles: false,
        mini: false,
        lineNumberGutterVisible: false,
        scrollPastEnd: true,
        autoHeight: false,
        maxScreenLineLength: 1000
      });

      expect(returnedPromise).toBe(element.component.getNextUpdatePromise());
      expect(changeSpy.callCount).toBe(1);
      expect(editor.getTabLength()).toBe(6);
      expect(editor.getSoftTabs()).toBe(false);
      expect(editor.isSoftWrapped()).toBe(true);
      expect(editor.getEditorWidthInChars()).toBe(40);
      expect(editor.getInvisibles()).toEqual({});
      expect(editor.isMini()).toBe(false);
      expect(editor.isLineNumberGutterVisible()).toBe(false);
      expect(editor.getScrollPastEnd()).toBe(true);
      expect(editor.getAutoHeight()).toBe(false);
    });
  });

  describe('title', () => {
    describe('.getTitle()', () => {
      it("uses the basename of the buffer's path as its title, or 'untitled' if the path is undefined", () => {
        expect(editor.getTitle()).toBe('sample.js');
        buffer.setPath(undefined);
        expect(editor.getTitle()).toBe('untitled');
      });
    });

    describe('.getLongTitle()', () => {
      it('returns file name when there is no opened file with identical name', () => {
        expect(editor.getLongTitle()).toBe('sample.js');
        buffer.setPath(undefined);
        expect(editor.getLongTitle()).toBe('untitled');
      });

      it("returns '<filename> — <parent-directory>' when opened files have identical file names", async () => {
        const editor1 = await atom.workspace.open(
          path.join('sample-theme-1', 'readme')
        );
        const editor2 = await atom.workspace.open(
          path.join('sample-theme-2', 'readme')
        );
        expect(editor1.getLongTitle()).toBe('readme \u2014 sample-theme-1');
        expect(editor2.getLongTitle()).toBe('readme \u2014 sample-theme-2');
      });

      it("returns '<filename> — <parent-directories>' when opened files have identical file names in subdirectories", async () => {
        const path1 = path.join('sample-theme-1', 'src', 'js');
        const path2 = path.join('sample-theme-2', 'src', 'js');
        const editor1 = await atom.workspace.open(path.join(path1, 'main.js'));
        const editor2 = await atom.workspace.open(path.join(path2, 'main.js'));
        expect(editor1.getLongTitle()).toBe(`main.js \u2014 ${path1}`);
        expect(editor2.getLongTitle()).toBe(`main.js \u2014 ${path2}`);
      });

      it("returns '<filename> — <parent-directories>' when opened files have identical file and same parent dir name", async () => {
        const editor1 = await atom.workspace.open(
          path.join('sample-theme-2', 'src', 'js', 'main.js')
        );
        const editor2 = await atom.workspace.open(
          path.join('sample-theme-2', 'src', 'js', 'plugin', 'main.js')
        );
        expect(editor1.getLongTitle()).toBe('main.js \u2014 js');
        expect(editor2.getLongTitle()).toBe(
          `main.js \u2014 ${path.join('js', 'plugin')}`
        );
      });

      it('returns the filename when the editor is not in the workspace', async () => {
        editor.onDidDestroy(() => {
          expect(editor.getLongTitle()).toBe('sample.js');
        });

        await atom.workspace.getActivePane().close();
        expect(editor.isDestroyed()).toBe(true);
      });
    });

    it('notifies ::onDidChangeTitle observers when the underlying buffer path changes', () => {
      const observed = [];
      editor.onDidChangeTitle(title => observed.push(title));

      buffer.setPath('/foo/bar/baz.txt');
      buffer.setPath(undefined);

      expect(observed).toEqual(['baz.txt', 'untitled']);
    });
  });

  describe('path', () => {
    it('notifies ::onDidChangePath observers when the underlying buffer path changes', () => {
      const observed = [];
      editor.onDidChangePath(filePath => observed.push(filePath));

      buffer.setPath(__filename);
      buffer.setPath(undefined);

      expect(observed).toEqual([__filename, undefined]);
    });
  });

  describe('encoding', () => {
    it('notifies ::onDidChangeEncoding observers when the editor encoding changes', () => {
      const observed = [];
      editor.onDidChangeEncoding(encoding => observed.push(encoding));

      editor.setEncoding('utf16le');
      editor.setEncoding('utf16le');
      editor.setEncoding('utf16be');
      editor.setEncoding();
      editor.setEncoding();

      expect(observed).toEqual(['utf16le', 'utf16be', 'utf8']);
    });
  });

  describe('cursor', () => {
    describe('.getLastCursor()', () => {
      it('returns the most recently created cursor', () => {
        editor.addCursorAtScreenPosition([1, 0]);
        const lastCursor = editor.addCursorAtScreenPosition([2, 0]);
        expect(editor.getLastCursor()).toBe(lastCursor);
      });

      it('creates a new cursor at (0, 0) if the last cursor has been destroyed', () => {
        editor.getLastCursor().destroy();
        expect(editor.getLastCursor().getBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('.getCursors()', () => {
      it('creates a new cursor at (0, 0) if the last cursor has been destroyed', () => {
        editor.getLastCursor().destroy();
        expect(editor.getCursors()[0].getBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('when the cursor moves', () => {
      it('clears a goal column established by vertical movement', () => {
        editor.setText('b');
        editor.setCursorBufferPosition([0, 0]);
        editor.insertNewline();
        editor.moveUp();
        editor.insertText('a');
        editor.moveDown();
        expect(editor.getCursorBufferPosition()).toEqual([1, 1]);
      });

      it('emits an event with the old position, new position, and the cursor that moved', () => {
        const cursorCallback = jasmine.createSpy('cursor-changed-position');
        const editorCallback = jasmine.createSpy(
          'editor-changed-cursor-position'
        );

        editor.getLastCursor().onDidChangePosition(cursorCallback);
        editor.onDidChangeCursorPosition(editorCallback);

        editor.setCursorBufferPosition([2, 4]);

        expect(editorCallback).toHaveBeenCalled();
        expect(cursorCallback).toHaveBeenCalled();
        const eventObject = editorCallback.mostRecentCall.args[0];
        expect(cursorCallback.mostRecentCall.args[0]).toEqual(eventObject);

        expect(eventObject.oldBufferPosition).toEqual([0, 0]);
        expect(eventObject.oldScreenPosition).toEqual([0, 0]);
        expect(eventObject.newBufferPosition).toEqual([2, 4]);
        expect(eventObject.newScreenPosition).toEqual([2, 4]);
        expect(eventObject.cursor).toBe(editor.getLastCursor());
      });
    });

    describe('.setCursorScreenPosition(screenPosition)', () => {
      it('clears a goal column established by vertical movement', () => {
        // set a goal column by moving down
        editor.setCursorScreenPosition({ row: 3, column: lineLengths[3] });
        editor.moveDown();
        expect(editor.getCursorScreenPosition().column).not.toBe(6);

        // clear the goal column by explicitly setting the cursor position
        editor.setCursorScreenPosition([4, 6]);
        expect(editor.getCursorScreenPosition().column).toBe(6);

        editor.moveDown();
        expect(editor.getCursorScreenPosition().column).toBe(6);
      });

      it('merges multiple cursors', () => {
        editor.setCursorScreenPosition([0, 0]);
        editor.addCursorAtScreenPosition([0, 1]);
        const [cursor1] = editor.getCursors();
        editor.setCursorScreenPosition([4, 7]);
        expect(editor.getCursors().length).toBe(1);
        expect(editor.getCursors()).toEqual([cursor1]);
        expect(editor.getCursorScreenPosition()).toEqual([4, 7]);
      });

      describe('when soft-wrap is enabled and code is folded', () => {
        beforeEach(() => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(50);
          editor.foldBufferRowRange(2, 3);
        });

        it('positions the cursor at the buffer position that corresponds to the given screen position', () => {
          editor.setCursorScreenPosition([9, 0]);
          expect(editor.getCursorBufferPosition()).toEqual([8, 11]);
        });
      });
    });

    describe('.moveUp()', () => {
      it('moves the cursor up', () => {
        editor.setCursorScreenPosition([2, 2]);
        editor.moveUp();
        expect(editor.getCursorScreenPosition()).toEqual([1, 2]);
      });

      it('retains the goal column across lines of differing length', () => {
        expect(lineLengths[6]).toBeGreaterThan(32);
        editor.setCursorScreenPosition({ row: 6, column: 32 });

        editor.moveUp();
        expect(editor.getCursorScreenPosition().column).toBe(lineLengths[5]);

        editor.moveUp();
        expect(editor.getCursorScreenPosition().column).toBe(lineLengths[4]);

        editor.moveUp();
        expect(editor.getCursorScreenPosition().column).toBe(32);
      });

      describe('when the cursor is on the first line', () => {
        it('moves the cursor to the beginning of the line, but retains the goal column', () => {
          editor.setCursorScreenPosition([0, 4]);
          editor.moveUp();
          expect(editor.getCursorScreenPosition()).toEqual([0, 0]);

          editor.moveDown();
          expect(editor.getCursorScreenPosition()).toEqual([1, 4]);
        });
      });

      describe('when there is a selection', () => {
        beforeEach(() => editor.setSelectedBufferRange([[4, 9], [5, 10]]));

        it('moves above the selection', () => {
          const cursor = editor.getLastCursor();
          editor.moveUp();
          expect(cursor.getBufferPosition()).toEqual([3, 9]);
        });
      });

      it('merges cursors when they overlap', () => {
        editor.addCursorAtScreenPosition([1, 0]);
        const [cursor1] = editor.getCursors();

        editor.moveUp();
        expect(editor.getCursors()).toEqual([cursor1]);
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
      });

      describe('when the cursor was moved down from the beginning of an indented soft-wrapped line', () => {
        it('moves to the beginning of the previous line', () => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(50);

          editor.setCursorScreenPosition([3, 0]);
          editor.moveDown();
          editor.moveDown();
          editor.moveUp();
          expect(editor.getCursorScreenPosition()).toEqual([4, 4]);
        });
      });
    });

    describe('.moveDown()', () => {
      it('moves the cursor down', () => {
        editor.setCursorScreenPosition([2, 2]);
        editor.moveDown();
        expect(editor.getCursorScreenPosition()).toEqual([3, 2]);
      });

      it('retains the goal column across lines of differing length', () => {
        editor.setCursorScreenPosition({ row: 3, column: lineLengths[3] });

        editor.moveDown();
        expect(editor.getCursorScreenPosition().column).toBe(lineLengths[4]);

        editor.moveDown();
        expect(editor.getCursorScreenPosition().column).toBe(lineLengths[5]);

        editor.moveDown();
        expect(editor.getCursorScreenPosition().column).toBe(lineLengths[3]);
      });

      describe('when the cursor is on the last line', () => {
        it('moves the cursor to the end of line, but retains the goal column when moving back up', () => {
          const lastLineIndex = buffer.getLines().length - 1;
          const lastLine = buffer.lineForRow(lastLineIndex);
          expect(lastLine.length).toBeGreaterThan(0);

          editor.setCursorScreenPosition({
            row: lastLineIndex,
            column: editor.getTabLength()
          });
          editor.moveDown();
          expect(editor.getCursorScreenPosition()).toEqual({
            row: lastLineIndex,
            column: lastLine.length
          });

          editor.moveUp();
          expect(editor.getCursorScreenPosition().column).toBe(
            editor.getTabLength()
          );
        });

        it('retains a goal column of 0 when moving back up', () => {
          const lastLineIndex = buffer.getLines().length - 1;
          const lastLine = buffer.lineForRow(lastLineIndex);
          expect(lastLine.length).toBeGreaterThan(0);

          editor.setCursorScreenPosition({ row: lastLineIndex, column: 0 });
          editor.moveDown();
          editor.moveUp();
          expect(editor.getCursorScreenPosition().column).toBe(0);
        });
      });

      describe('when the cursor is at the beginning of an indented soft-wrapped line', () => {
        it("moves to the beginning of the line's continuation on the next screen row", () => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(50);

          editor.setCursorScreenPosition([3, 0]);
          editor.moveDown();
          expect(editor.getCursorScreenPosition()).toEqual([4, 4]);
        });
      });

      describe('when there is a selection', () => {
        beforeEach(() => editor.setSelectedBufferRange([[4, 9], [5, 10]]));

        it('moves below the selection', () => {
          const cursor = editor.getLastCursor();
          editor.moveDown();
          expect(cursor.getBufferPosition()).toEqual([6, 10]);
        });
      });

      it('merges cursors when they overlap', () => {
        editor.setCursorScreenPosition([12, 2]);
        editor.addCursorAtScreenPosition([11, 2]);
        const [cursor1] = editor.getCursors();

        editor.moveDown();
        expect(editor.getCursors()).toEqual([cursor1]);
        expect(cursor1.getBufferPosition()).toEqual([12, 2]);
      });
    });

    describe('.moveLeft()', () => {
      it('moves the cursor by one column to the left', () => {
        editor.setCursorScreenPosition([1, 8]);
        editor.moveLeft();
        expect(editor.getCursorScreenPosition()).toEqual([1, 7]);
      });

      it('moves the cursor by n columns to the left', () => {
        editor.setCursorScreenPosition([1, 8]);
        editor.moveLeft(4);
        expect(editor.getCursorScreenPosition()).toEqual([1, 4]);
      });

      it('moves the cursor by two rows up when the columnCount is longer than an entire line', () => {
        editor.setCursorScreenPosition([2, 2]);
        editor.moveLeft(34);
        expect(editor.getCursorScreenPosition()).toEqual([0, 29]);
      });

      it('moves the cursor to the beginning columnCount is longer than the position in the buffer', () => {
        editor.setCursorScreenPosition([1, 0]);
        editor.moveLeft(100);
        expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
      });

      describe('when the cursor is in the first column', () => {
        describe('when there is a previous line', () => {
          it('wraps to the end of the previous line', () => {
            editor.setCursorScreenPosition({ row: 1, column: 0 });
            editor.moveLeft();
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 0,
              column: buffer.lineForRow(0).length
            });
          });

          it('moves the cursor by one row up and n columns to the left', () => {
            editor.setCursorScreenPosition([1, 0]);
            editor.moveLeft(4);
            expect(editor.getCursorScreenPosition()).toEqual([0, 26]);
          });
        });

        describe('when the next line is empty', () => {
          it('wraps to the beginning of the previous line', () => {
            editor.setCursorScreenPosition([11, 0]);
            editor.moveLeft();
            expect(editor.getCursorScreenPosition()).toEqual([10, 0]);
          });
        });

        describe('when line is wrapped and follow previous line indentation', () => {
          beforeEach(() => {
            editor.setSoftWrapped(true);
            editor.setDefaultCharWidth(1);
            editor.setEditorWidthInChars(50);
          });

          it('wraps to the end of the previous line', () => {
            editor.setCursorScreenPosition([4, 4]);
            editor.moveLeft();
            expect(editor.getCursorScreenPosition()).toEqual([3, 46]);
          });
        });

        describe('when the cursor is on the first line', () => {
          it('remains in the same position (0,0)', () => {
            editor.setCursorScreenPosition({ row: 0, column: 0 });
            editor.moveLeft();
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 0,
              column: 0
            });
          });

          it('remains in the same position (0,0) when columnCount is specified', () => {
            editor.setCursorScreenPosition([0, 0]);
            editor.moveLeft(4);
            expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
          });
        });
      });

      describe('when softTabs is enabled and the cursor is preceded by leading whitespace', () => {
        it('skips tabLength worth of whitespace at a time', () => {
          editor.setCursorBufferPosition([5, 6]);

          editor.moveLeft();
          expect(editor.getCursorBufferPosition()).toEqual([5, 4]);
        });
      });

      describe('when there is a selection', () => {
        beforeEach(() => editor.setSelectedBufferRange([[5, 22], [5, 27]]));

        it('moves to the left of the selection', () => {
          const cursor = editor.getLastCursor();
          editor.moveLeft();
          expect(cursor.getBufferPosition()).toEqual([5, 22]);

          editor.moveLeft();
          expect(cursor.getBufferPosition()).toEqual([5, 21]);
        });
      });

      it('merges cursors when they overlap', () => {
        editor.setCursorScreenPosition([0, 0]);
        editor.addCursorAtScreenPosition([0, 1]);

        const [cursor1] = editor.getCursors();
        editor.moveLeft();
        expect(editor.getCursors()).toEqual([cursor1]);
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('.moveRight()', () => {
      it('moves the cursor by one column to the right', () => {
        editor.setCursorScreenPosition([3, 3]);
        editor.moveRight();
        expect(editor.getCursorScreenPosition()).toEqual([3, 4]);
      });

      it('moves the cursor by n columns to the right', () => {
        editor.setCursorScreenPosition([3, 7]);
        editor.moveRight(4);
        expect(editor.getCursorScreenPosition()).toEqual([3, 11]);
      });

      it('moves the cursor by two rows down when the columnCount is longer than an entire line', () => {
        editor.setCursorScreenPosition([0, 29]);
        editor.moveRight(34);
        expect(editor.getCursorScreenPosition()).toEqual([2, 2]);
      });

      it('moves the cursor to the end of the buffer when columnCount is longer than the number of characters following the cursor position', () => {
        editor.setCursorScreenPosition([11, 5]);
        editor.moveRight(100);
        expect(editor.getCursorScreenPosition()).toEqual([12, 2]);
      });

      describe('when the cursor is on the last column of a line', () => {
        describe('when there is a subsequent line', () => {
          it('wraps to the beginning of the next line', () => {
            editor.setCursorScreenPosition([0, buffer.lineForRow(0).length]);
            editor.moveRight();
            expect(editor.getCursorScreenPosition()).toEqual([1, 0]);
          });

          it('moves the cursor by one row down and n columns to the right', () => {
            editor.setCursorScreenPosition([0, buffer.lineForRow(0).length]);
            editor.moveRight(4);
            expect(editor.getCursorScreenPosition()).toEqual([1, 3]);
          });
        });

        describe('when the next line is empty', () => {
          it('wraps to the beginning of the next line', () => {
            editor.setCursorScreenPosition([9, 4]);
            editor.moveRight();
            expect(editor.getCursorScreenPosition()).toEqual([10, 0]);
          });
        });

        describe('when the cursor is on the last line', () => {
          it('remains in the same position', () => {
            const lastLineIndex = buffer.getLines().length - 1;
            const lastLine = buffer.lineForRow(lastLineIndex);
            expect(lastLine.length).toBeGreaterThan(0);

            const lastPosition = {
              row: lastLineIndex,
              column: lastLine.length
            };
            editor.setCursorScreenPosition(lastPosition);
            editor.moveRight();

            expect(editor.getCursorScreenPosition()).toEqual(lastPosition);
          });
        });
      });

      describe('when there is a selection', () => {
        beforeEach(() => editor.setSelectedBufferRange([[5, 22], [5, 27]]));

        it('moves to the left of the selection', () => {
          const cursor = editor.getLastCursor();
          editor.moveRight();
          expect(cursor.getBufferPosition()).toEqual([5, 27]);

          editor.moveRight();
          expect(cursor.getBufferPosition()).toEqual([5, 28]);
        });
      });

      it('merges cursors when they overlap', () => {
        editor.setCursorScreenPosition([12, 2]);
        editor.addCursorAtScreenPosition([12, 1]);
        const [cursor1] = editor.getCursors();

        editor.moveRight();
        expect(editor.getCursors()).toEqual([cursor1]);
        expect(cursor1.getBufferPosition()).toEqual([12, 2]);
      });
    });

    describe('.moveToTop()', () => {
      it('moves the cursor to the top of the buffer', () => {
        editor.setCursorScreenPosition([11, 1]);
        editor.addCursorAtScreenPosition([12, 0]);
        editor.moveToTop();
        expect(editor.getCursors().length).toBe(1);
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('.moveToBottom()', () => {
      it('moves the cursor to the bottom of the buffer', () => {
        editor.setCursorScreenPosition([0, 0]);
        editor.addCursorAtScreenPosition([1, 0]);
        editor.moveToBottom();
        expect(editor.getCursors().length).toBe(1);
        expect(editor.getCursorBufferPosition()).toEqual([12, 2]);
      });
    });

    describe('.moveToBeginningOfScreenLine()', () => {
      describe('when soft wrap is on', () => {
        it('moves cursor to the beginning of the screen line', () => {
          editor.setSoftWrapped(true);
          editor.setEditorWidthInChars(10);
          editor.setCursorScreenPosition([1, 2]);
          editor.moveToBeginningOfScreenLine();
          const cursor = editor.getLastCursor();
          expect(cursor.getScreenPosition()).toEqual([1, 0]);
        });
      });

      describe('when soft wrap is off', () => {
        it('moves cursor to the beginning of the line', () => {
          editor.setCursorScreenPosition([0, 5]);
          editor.addCursorAtScreenPosition([1, 7]);
          editor.moveToBeginningOfScreenLine();
          expect(editor.getCursors().length).toBe(2);
          const [cursor1, cursor2] = editor.getCursors();
          expect(cursor1.getBufferPosition()).toEqual([0, 0]);
          expect(cursor2.getBufferPosition()).toEqual([1, 0]);
        });
      });
    });

    describe('.moveToEndOfScreenLine()', () => {
      describe('when soft wrap is on', () => {
        it('moves cursor to the beginning of the screen line', () => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(10);
          editor.setCursorScreenPosition([1, 2]);
          editor.moveToEndOfScreenLine();
          const cursor = editor.getLastCursor();
          expect(cursor.getScreenPosition()).toEqual([1, 9]);
        });
      });

      describe('when soft wrap is off', () => {
        it('moves cursor to the end of line', () => {
          editor.setCursorScreenPosition([0, 0]);
          editor.addCursorAtScreenPosition([1, 0]);
          editor.moveToEndOfScreenLine();
          expect(editor.getCursors().length).toBe(2);
          const [cursor1, cursor2] = editor.getCursors();
          expect(cursor1.getBufferPosition()).toEqual([0, 29]);
          expect(cursor2.getBufferPosition()).toEqual([1, 30]);
        });
      });
    });

    describe('.moveToBeginningOfLine()', () => {
      it('moves cursor to the beginning of the buffer line', () => {
        editor.setSoftWrapped(true);
        editor.setDefaultCharWidth(1);
        editor.setEditorWidthInChars(10);
        editor.setCursorScreenPosition([1, 2]);
        editor.moveToBeginningOfLine();
        const cursor = editor.getLastCursor();
        expect(cursor.getScreenPosition()).toEqual([0, 0]);
      });
    });

    describe('.moveToEndOfLine()', () => {
      it('moves cursor to the end of the buffer line', () => {
        editor.setSoftWrapped(true);
        editor.setDefaultCharWidth(1);
        editor.setEditorWidthInChars(10);
        editor.setCursorScreenPosition([0, 2]);
        editor.moveToEndOfLine();
        const cursor = editor.getLastCursor();
        expect(cursor.getScreenPosition()).toEqual([4, 4]);
      });
    });

    describe('.moveToFirstCharacterOfLine()', () => {
      describe('when soft wrap is on', () => {
        it("moves to the first character of the current screen line or the beginning of the screen line if it's already on the first character", () => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(10);
          editor.setCursorScreenPosition([2, 5]);
          editor.addCursorAtScreenPosition([8, 7]);

          editor.moveToFirstCharacterOfLine();
          const [cursor1, cursor2] = editor.getCursors();
          expect(cursor1.getScreenPosition()).toEqual([2, 0]);
          expect(cursor2.getScreenPosition()).toEqual([8, 2]);

          editor.moveToFirstCharacterOfLine();
          expect(cursor1.getScreenPosition()).toEqual([2, 0]);
          expect(cursor2.getScreenPosition()).toEqual([8, 2]);
        });
      });

      describe('when soft wrap is off', () => {
        it("moves to the first character of the current line or the beginning of the line if it's already on the first character", () => {
          editor.setCursorScreenPosition([0, 5]);
          editor.addCursorAtScreenPosition([1, 7]);

          editor.moveToFirstCharacterOfLine();
          const [cursor1, cursor2] = editor.getCursors();
          expect(cursor1.getBufferPosition()).toEqual([0, 0]);
          expect(cursor2.getBufferPosition()).toEqual([1, 2]);

          editor.moveToFirstCharacterOfLine();
          expect(cursor1.getBufferPosition()).toEqual([0, 0]);
          expect(cursor2.getBufferPosition()).toEqual([1, 0]);
        });

        it('moves to the beginning of the line if it only contains whitespace ', () => {
          editor.setText('first\n    \nthird');
          editor.setCursorScreenPosition([1, 2]);
          editor.moveToFirstCharacterOfLine();
          const cursor = editor.getLastCursor();
          expect(cursor.getBufferPosition()).toEqual([1, 0]);
        });

        describe('when invisible characters are enabled with soft tabs', () => {
          it('moves to the first character of the current line without being confused by the invisible characters', () => {
            editor.update({ showInvisibles: true });
            editor.setCursorScreenPosition([1, 7]);
            editor.moveToFirstCharacterOfLine();
            expect(editor.getCursorBufferPosition()).toEqual([1, 2]);
            editor.moveToFirstCharacterOfLine();
            expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
          });
        });

        describe('when invisible characters are enabled with hard tabs', () => {
          it('moves to the first character of the current line without being confused by the invisible characters', () => {
            editor.update({ showInvisibles: true });
            buffer.setTextInRange([[1, 0], [1, Infinity]], '\t\t\ta', {
              normalizeLineEndings: false
            });

            editor.setCursorScreenPosition([1, 7]);
            editor.moveToFirstCharacterOfLine();
            expect(editor.getCursorBufferPosition()).toEqual([1, 3]);
            editor.moveToFirstCharacterOfLine();
            expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
          });
        });
      });

      it('clears the goal column', () => {
        editor.setText('first\n\nthird');
        editor.setCursorScreenPosition([0, 3]);
        editor.moveDown();
        editor.moveToFirstCharacterOfLine();
        editor.moveDown();
        expect(editor.getCursorBufferPosition()).toEqual([2, 0]);
      });
    });

    describe('.moveToBeginningOfWord()', () => {
      it('moves the cursor to the beginning of the word', () => {
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([1, 12]);
        editor.addCursorAtBufferPosition([3, 0]);
        const [cursor1, cursor2, cursor3] = editor.getCursors();

        editor.moveToBeginningOfWord();

        expect(cursor1.getBufferPosition()).toEqual([0, 4]);
        expect(cursor2.getBufferPosition()).toEqual([1, 11]);
        expect(cursor3.getBufferPosition()).toEqual([2, 39]);
      });

      it('does not fail at position [0, 0]', () => {
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToBeginningOfWord();
      });

      it('treats lines with only whitespace as a word', () => {
        editor.setCursorBufferPosition([11, 0]);
        editor.moveToBeginningOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
      });

      it('treats lines with only whitespace as a word (CRLF line ending)', () => {
        editor.buffer.setText(buffer.getText().replace(/\n/g, '\r\n'));
        editor.setCursorBufferPosition([11, 0]);
        editor.moveToBeginningOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
      });

      it('works when the current line is blank', () => {
        editor.setCursorBufferPosition([10, 0]);
        editor.moveToBeginningOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([9, 2]);
      });

      it('works when the current line is blank (CRLF line ending)', () => {
        editor.buffer.setText(buffer.getText().replace(/\n/g, '\r\n'));
        editor.setCursorBufferPosition([10, 0]);
        editor.moveToBeginningOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([9, 2]);
        editor.buffer.setText(buffer.getText().replace(/\r\n/g, '\n'));
      });
    });

    describe('.moveToPreviousWordBoundary()', () => {
      it('moves the cursor to the previous word boundary', () => {
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([2, 0]);
        editor.addCursorAtBufferPosition([2, 4]);
        editor.addCursorAtBufferPosition([3, 14]);
        const [cursor1, cursor2, cursor3, cursor4] = editor.getCursors();

        editor.moveToPreviousWordBoundary();

        expect(cursor1.getBufferPosition()).toEqual([0, 4]);
        expect(cursor2.getBufferPosition()).toEqual([1, 30]);
        expect(cursor3.getBufferPosition()).toEqual([2, 0]);
        expect(cursor4.getBufferPosition()).toEqual([3, 13]);
      });
    });

    describe('.moveToNextWordBoundary()', () => {
      it('moves the cursor to the previous word boundary', () => {
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([2, 40]);
        editor.addCursorAtBufferPosition([3, 0]);
        editor.addCursorAtBufferPosition([3, 30]);
        const [cursor1, cursor2, cursor3, cursor4] = editor.getCursors();

        editor.moveToNextWordBoundary();

        expect(cursor1.getBufferPosition()).toEqual([0, 13]);
        expect(cursor2.getBufferPosition()).toEqual([3, 0]);
        expect(cursor3.getBufferPosition()).toEqual([3, 4]);
        expect(cursor4.getBufferPosition()).toEqual([3, 31]);
      });
    });

    describe('.moveToEndOfWord()', () => {
      it('moves the cursor to the end of the word', () => {
        editor.setCursorBufferPosition([0, 6]);
        editor.addCursorAtBufferPosition([1, 10]);
        editor.addCursorAtBufferPosition([2, 40]);
        const [cursor1, cursor2, cursor3] = editor.getCursors();

        editor.moveToEndOfWord();

        expect(cursor1.getBufferPosition()).toEqual([0, 13]);
        expect(cursor2.getBufferPosition()).toEqual([1, 12]);
        expect(cursor3.getBufferPosition()).toEqual([3, 7]);
      });

      it('does not blow up when there is no next word', () => {
        editor.setCursorBufferPosition([Infinity, Infinity]);
        const endPosition = editor.getCursorBufferPosition();
        editor.moveToEndOfWord();
        expect(editor.getCursorBufferPosition()).toEqual(endPosition);
      });

      it('treats lines with only whitespace as a word', () => {
        editor.setCursorBufferPosition([9, 4]);
        editor.moveToEndOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
      });

      it('treats lines with only whitespace as a word (CRLF line ending)', () => {
        editor.buffer.setText(buffer.getText().replace(/\n/g, '\r\n'));
        editor.setCursorBufferPosition([9, 4]);
        editor.moveToEndOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
      });

      it('works when the current line is blank', () => {
        editor.setCursorBufferPosition([10, 0]);
        editor.moveToEndOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([11, 8]);
      });

      it('works when the current line is blank (CRLF line ending)', () => {
        editor.buffer.setText(buffer.getText().replace(/\n/g, '\r\n'));
        editor.setCursorBufferPosition([10, 0]);
        editor.moveToEndOfWord();
        expect(editor.getCursorBufferPosition()).toEqual([11, 8]);
      });
    });

    describe('.moveToBeginningOfNextWord()', () => {
      it('moves the cursor before the first character of the next word', () => {
        editor.setCursorBufferPosition([0, 6]);
        editor.addCursorAtBufferPosition([1, 11]);
        editor.addCursorAtBufferPosition([2, 0]);
        const [cursor1, cursor2, cursor3] = editor.getCursors();

        editor.moveToBeginningOfNextWord();

        expect(cursor1.getBufferPosition()).toEqual([0, 14]);
        expect(cursor2.getBufferPosition()).toEqual([1, 13]);
        expect(cursor3.getBufferPosition()).toEqual([2, 4]);

        // When the cursor is on whitespace
        editor.setText('ab cde- ');
        editor.setCursorBufferPosition([0, 2]);
        const cursor = editor.getLastCursor();
        editor.moveToBeginningOfNextWord();

        expect(cursor.getBufferPosition()).toEqual([0, 3]);
      });

      it('does not blow up when there is no next word', () => {
        editor.setCursorBufferPosition([Infinity, Infinity]);
        const endPosition = editor.getCursorBufferPosition();
        editor.moveToBeginningOfNextWord();
        expect(editor.getCursorBufferPosition()).toEqual(endPosition);
      });

      it('treats lines with only whitespace as a word', () => {
        editor.setCursorBufferPosition([9, 4]);
        editor.moveToBeginningOfNextWord();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
      });

      it('works when the current line is blank', () => {
        editor.setCursorBufferPosition([10, 0]);
        editor.moveToBeginningOfNextWord();
        expect(editor.getCursorBufferPosition()).toEqual([11, 9]);
      });
    });

    describe('.moveToPreviousSubwordBoundary', () => {
      it('does not move the cursor when there is no previous subword boundary', () => {
        editor.setText('');
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });

      it('stops at word and underscore boundaries', () => {
        editor.setText('sub_word \n');
        editor.setCursorBufferPosition([0, 9]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 8]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);

        editor.setText(' word\n');
        editor.setCursorBufferPosition([0, 3]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
      });

      it('stops at camelCase boundaries', () => {
        editor.setText(' getPreviousWord\n');
        editor.setCursorBufferPosition([0, 16]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 12]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
      });

      it('stops at camelCase boundaries with non-ascii characters', () => {
        editor.setText(' gétÁrevìôüsWord\n');
        editor.setCursorBufferPosition([0, 16]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 12]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
      });

      it('skips consecutive non-word characters', () => {
        editor.setText('e, => \n');
        editor.setCursorBufferPosition([0, 6]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 3]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
      });

      it('skips consecutive uppercase characters', () => {
        editor.setText(' AAADF \n');
        editor.setCursorBufferPosition([0, 7]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 6]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.setText('ALPhA\n');
        editor.setCursorBufferPosition([0, 4]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      });

      it('skips consecutive uppercase non-ascii letters', () => {
        editor.setText(' ÀÁÅDF \n');
        editor.setCursorBufferPosition([0, 7]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 6]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.setText('ALPhA\n');
        editor.setCursorBufferPosition([0, 4]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      });

      it('skips consecutive numbers', () => {
        editor.setText(' 88 \n');
        editor.setCursorBufferPosition([0, 4]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 3]);

        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
      });

      it('works with multiple cursors', () => {
        editor.setText('curOp\ncursorOptions\n');
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([1, 13]);
        const [cursor1, cursor2] = editor.getCursors();

        editor.moveToPreviousSubwordBoundary();

        expect(cursor1.getBufferPosition()).toEqual([0, 3]);
        expect(cursor2.getBufferPosition()).toEqual([1, 6]);
      });

      it('works with non-English characters', () => {
        editor.setText('supåTøåst \n');
        editor.setCursorBufferPosition([0, 9]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.setText('supaÖast \n');
        editor.setCursorBufferPosition([0, 8]);
        editor.moveToPreviousSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      });
    });

    describe('.moveToNextSubwordBoundary', () => {
      it('does not move the cursor when there is no next subword boundary', () => {
        editor.setText('');
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });

      it('stops at word and underscore boundaries', () => {
        editor.setText(' sub_word \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 9]);

        editor.setText('word \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      });

      it('stops at camelCase boundaries', () => {
        editor.setText('getPreviousWord \n');
        editor.setCursorBufferPosition([0, 0]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 3]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 11]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 15]);
      });

      it('skips consecutive non-word characters', () => {
        editor.setText(', => \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      });

      it('skips consecutive uppercase characters', () => {
        editor.setText(' AAADF \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 6]);

        editor.setText('ALPhA\n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      });

      it('skips consecutive numbers', () => {
        editor.setText(' 88 \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 1]);

        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 3]);
      });

      it('works with multiple cursors', () => {
        editor.setText('curOp\ncursorOptions\n');
        editor.setCursorBufferPosition([0, 0]);
        editor.addCursorAtBufferPosition([1, 0]);
        const [cursor1, cursor2] = editor.getCursors();

        editor.moveToNextSubwordBoundary();
        expect(cursor1.getBufferPosition()).toEqual([0, 3]);
        expect(cursor2.getBufferPosition()).toEqual([1, 6]);
      });

      it('works with non-English characters', () => {
        editor.setText('supåTøåst \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);

        editor.setText('supaÖast \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToNextSubwordBoundary();
        expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      });
    });

    describe('.moveToBeginningOfNextParagraph()', () => {
      it('moves the cursor before the first line of the next paragraph', () => {
        editor.setCursorBufferPosition([0, 6]);
        editor.foldBufferRow(4);

        editor.moveToBeginningOfNextParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);

        editor.setText('');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToBeginningOfNextParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });

      it('moves the cursor before the first line of the next paragraph (CRLF line endings)', () => {
        editor.setText(editor.getText().replace(/\n/g, '\r\n'));

        editor.setCursorBufferPosition([0, 6]);
        editor.foldBufferRow(4);

        editor.moveToBeginningOfNextParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([10, 0]);

        editor.setText('');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToBeginningOfNextParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('.moveToBeginningOfPreviousParagraph()', () => {
      it('moves the cursor before the first line of the previous paragraph', () => {
        editor.setCursorBufferPosition([10, 0]);
        editor.foldBufferRow(4);

        editor.moveToBeginningOfPreviousParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);

        editor.setText('');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToBeginningOfPreviousParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });

      it('moves the cursor before the first line of the previous paragraph (CRLF line endings)', () => {
        editor.setText(editor.getText().replace(/\n/g, '\r\n'));

        editor.setCursorBufferPosition([10, 0]);
        editor.foldBufferRow(4);

        editor.moveToBeginningOfPreviousParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);

        editor.setText('');
        editor.setCursorBufferPosition([0, 0]);
        editor.moveToBeginningOfPreviousParagraph();
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
      });
    });

    describe('.getCurrentParagraphBufferRange()', () => {
      it('returns the buffer range of the current paragraph, delimited by blank lines or the beginning / end of the file', () => {
        buffer.setText(
          '  ' +
            dedent`
          I am the first paragraph,
          bordered by the beginning of
          the file
          ${'   '}

            I am the second paragraph
          with blank lines above and below
          me.

          I am the last paragraph,
          bordered by the end of the file.\
        `
        );

        // in a paragraph
        editor.setCursorBufferPosition([1, 7]);
        expect(editor.getCurrentParagraphBufferRange()).toEqual([
          [0, 0],
          [2, 8]
        ]);

        editor.setCursorBufferPosition([7, 1]);
        expect(editor.getCurrentParagraphBufferRange()).toEqual([
          [5, 0],
          [7, 3]
        ]);

        editor.setCursorBufferPosition([9, 10]);
        expect(editor.getCurrentParagraphBufferRange()).toEqual([
          [9, 0],
          [10, 32]
        ]);

        // between paragraphs
        editor.setCursorBufferPosition([3, 1]);
        expect(editor.getCurrentParagraphBufferRange()).toBeUndefined();
      });

      it('will limit paragraph range to comments', () => {
        atom.grammars.assignLanguageMode(editor.getBuffer(), 'source.js');
        editor.setText(dedent`
          var quicksort = function () {
            /* Single line comment block */
            var sort = function(items) {};

            /*
            A multiline
            comment is here
            */
            var sort = function(items) {};

            // A comment
            //
            // Multiple comment
            // lines
            var sort = function(items) {};
            // comment line after fn

            var nosort = function(items) {
              item;
            }

          };\
        `);

        function paragraphBufferRangeForRow(row) {
          editor.setCursorBufferPosition([row, 0]);
          return editor.getLastCursor().getCurrentParagraphBufferRange();
        }

        expect(paragraphBufferRangeForRow(0)).toEqual([[0, 0], [0, 29]]);
        expect(paragraphBufferRangeForRow(1)).toEqual([[1, 0], [1, 33]]);
        expect(paragraphBufferRangeForRow(2)).toEqual([[2, 0], [2, 32]]);
        expect(paragraphBufferRangeForRow(3)).toBeFalsy();
        expect(paragraphBufferRangeForRow(4)).toEqual([[4, 0], [7, 4]]);
        expect(paragraphBufferRangeForRow(5)).toEqual([[4, 0], [7, 4]]);
        expect(paragraphBufferRangeForRow(6)).toEqual([[4, 0], [7, 4]]);
        expect(paragraphBufferRangeForRow(7)).toEqual([[4, 0], [7, 4]]);
        expect(paragraphBufferRangeForRow(8)).toEqual([[8, 0], [8, 32]]);
        expect(paragraphBufferRangeForRow(9)).toBeFalsy();
        expect(paragraphBufferRangeForRow(10)).toEqual([[10, 0], [13, 10]]);
        expect(paragraphBufferRangeForRow(11)).toEqual([[10, 0], [13, 10]]);
        expect(paragraphBufferRangeForRow(12)).toEqual([[10, 0], [13, 10]]);
        expect(paragraphBufferRangeForRow(14)).toEqual([[14, 0], [14, 32]]);
        expect(paragraphBufferRangeForRow(15)).toEqual([[15, 0], [15, 26]]);
        expect(paragraphBufferRangeForRow(18)).toEqual([[17, 0], [19, 3]]);
      });
    });

    describe('getCursorAtScreenPosition(screenPosition)', () => {
      it('returns the cursor at the given screenPosition', () => {
        const cursor1 = editor.addCursorAtScreenPosition([0, 2]);
        const cursor2 = editor.getCursorAtScreenPosition(
          cursor1.getScreenPosition()
        );
        expect(cursor2).toBe(cursor1);
      });
    });

    describe('::getCursorScreenPositions()', () => {
      it('returns the cursor positions in the order they were added', () => {
        editor.foldBufferRow(4);
        editor.addCursorAtBufferPosition([8, 5]);
        editor.addCursorAtBufferPosition([3, 5]);

        expect(editor.getCursorScreenPositions()).toEqual([
          [0, 0],
          [5, 5],
          [3, 5]
        ]);
      });
    });

    describe('::getCursorsOrderedByBufferPosition()', () => {
      it('returns all cursors ordered by buffer positions', () => {
        const originalCursor = editor.getLastCursor();
        const cursor1 = editor.addCursorAtBufferPosition([8, 5]);
        const cursor2 = editor.addCursorAtBufferPosition([4, 5]);
        expect(editor.getCursorsOrderedByBufferPosition()).toEqual([
          originalCursor,
          cursor2,
          cursor1
        ]);
      });
    });

    describe('addCursorAtScreenPosition(screenPosition)', () => {
      describe('when a cursor already exists at the position', () => {
        it('returns the existing cursor', () => {
          const cursor1 = editor.addCursorAtScreenPosition([0, 2]);
          const cursor2 = editor.addCursorAtScreenPosition([0, 2]);
          expect(cursor2).toBe(cursor1);
        });
      });
    });

    describe('addCursorAtBufferPosition(bufferPosition)', () => {
      describe('when a cursor already exists at the position', () => {
        it('returns the existing cursor', () => {
          const cursor1 = editor.addCursorAtBufferPosition([1, 4]);
          const cursor2 = editor.addCursorAtBufferPosition([1, 4]);
          expect(cursor2.marker).toBe(cursor1.marker);
        });
      });
    });

    describe('.getCursorScope()', () => {
      it('returns the current scope', () => {
        const descriptor = editor.getCursorScope();
        expect(descriptor.scopes).toContain('source.js');
      });
    });
  });

  describe('selection', () => {
    let selection;

    beforeEach(() => {
      selection = editor.getLastSelection();
    });

    describe('.getLastSelection()', () => {
      it('creates a new selection at (0, 0) if the last selection has been destroyed', () => {
        editor.getLastSelection().destroy();
        expect(editor.getLastSelection().getBufferRange()).toEqual([
          [0, 0],
          [0, 0]
        ]);
      });

      it("doesn't get stuck in a infinite loop when called from ::onDidAddCursor after the last selection has been destroyed (regression)", () => {
        let callCount = 0;
        editor.getLastSelection().destroy();
        editor.onDidAddCursor(function(cursor) {
          callCount++;
          editor.getLastSelection();
        });
        expect(editor.getLastSelection().getBufferRange()).toEqual([
          [0, 0],
          [0, 0]
        ]);
        expect(callCount).toBe(1);
      });
    });

    describe('.getSelections()', () => {
      it('creates a new selection at (0, 0) if the last selection has been destroyed', () => {
        editor.getLastSelection().destroy();
        expect(editor.getSelections()[0].getBufferRange()).toEqual([
          [0, 0],
          [0, 0]
        ]);
      });
    });

    describe('when the selection range changes', () => {
      it('emits an event with the old range, new range, and the selection that moved', () => {
        let rangeChangedHandler;
        editor.setSelectedBufferRange([[3, 0], [4, 5]]);

        editor.onDidChangeSelectionRange(
          (rangeChangedHandler = jasmine.createSpy())
        );
        editor.selectToBufferPosition([6, 2]);

        expect(rangeChangedHandler).toHaveBeenCalled();
        const eventObject = rangeChangedHandler.mostRecentCall.args[0];

        expect(eventObject.oldBufferRange).toEqual([[3, 0], [4, 5]]);
        expect(eventObject.oldScreenRange).toEqual([[3, 0], [4, 5]]);
        expect(eventObject.newBufferRange).toEqual([[3, 0], [6, 2]]);
        expect(eventObject.newScreenRange).toEqual([[3, 0], [6, 2]]);
        expect(eventObject.selection).toBe(selection);
      });
    });

    describe('.selectUp/Down/Left/Right()', () => {
      it("expands each selection to its cursor's new location", () => {
        editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[3, 16], [3, 21]]]);
        const [selection1, selection2] = editor.getSelections();

        editor.selectRight();
        expect(selection1.getBufferRange()).toEqual([[0, 9], [0, 14]]);
        expect(selection2.getBufferRange()).toEqual([[3, 16], [3, 22]]);

        editor.selectLeft();
        editor.selectLeft();
        expect(selection1.getBufferRange()).toEqual([[0, 9], [0, 12]]);
        expect(selection2.getBufferRange()).toEqual([[3, 16], [3, 20]]);

        editor.selectDown();
        expect(selection1.getBufferRange()).toEqual([[0, 9], [1, 12]]);
        expect(selection2.getBufferRange()).toEqual([[3, 16], [4, 20]]);

        editor.selectUp();
        expect(selection1.getBufferRange()).toEqual([[0, 9], [0, 12]]);
        expect(selection2.getBufferRange()).toEqual([[3, 16], [3, 20]]);
      });

      it('merges selections when they intersect when moving down', () => {
        editor.setSelectedBufferRanges([
          [[0, 9], [0, 13]],
          [[1, 10], [1, 20]],
          [[2, 15], [3, 25]]
        ]);
        const [selection1] = editor.getSelections();

        editor.selectDown();
        expect(editor.getSelections()).toEqual([selection1]);
        expect(selection1.getScreenRange()).toEqual([[0, 9], [4, 25]]);
        expect(selection1.isReversed()).toBeFalsy();
      });

      it('merges selections when they intersect when moving up', () => {
        editor.setSelectedBufferRanges(
          [[[0, 9], [0, 13]], [[1, 10], [1, 20]]],
          { reversed: true }
        );
        const [selection1] = editor.getSelections();

        editor.selectUp();
        expect(editor.getSelections().length).toBe(1);
        expect(editor.getSelections()).toEqual([selection1]);
        expect(selection1.getScreenRange()).toEqual([[0, 0], [1, 20]]);
        expect(selection1.isReversed()).toBeTruthy();
      });

      it('merges selections when they intersect when moving left', () => {
        editor.setSelectedBufferRanges(
          [[[0, 9], [0, 13]], [[0, 13], [1, 20]]],
          { reversed: true }
        );
        const [selection1] = editor.getSelections();

        editor.selectLeft();
        expect(editor.getSelections()).toEqual([selection1]);
        expect(selection1.getScreenRange()).toEqual([[0, 8], [1, 20]]);
        expect(selection1.isReversed()).toBeTruthy();
      });

      it('merges selections when they intersect when moving right', () => {
        editor.setSelectedBufferRanges([[[0, 9], [0, 14]], [[0, 14], [1, 20]]]);
        const [selection1] = editor.getSelections();

        editor.selectRight();
        expect(editor.getSelections()).toEqual([selection1]);
        expect(selection1.getScreenRange()).toEqual([[0, 9], [1, 21]]);
        expect(selection1.isReversed()).toBeFalsy();
      });

      describe('when counts are passed into the selection functions', () => {
        it("expands each selection to its cursor's new location", () => {
          editor.setSelectedBufferRanges([
            [[0, 9], [0, 13]],
            [[3, 16], [3, 21]]
          ]);
          const [selection1, selection2] = editor.getSelections();

          editor.selectRight(2);
          expect(selection1.getBufferRange()).toEqual([[0, 9], [0, 15]]);
          expect(selection2.getBufferRange()).toEqual([[3, 16], [3, 23]]);

          editor.selectLeft(3);
          expect(selection1.getBufferRange()).toEqual([[0, 9], [0, 12]]);
          expect(selection2.getBufferRange()).toEqual([[3, 16], [3, 20]]);

          editor.selectDown(3);
          expect(selection1.getBufferRange()).toEqual([[0, 9], [3, 12]]);
          expect(selection2.getBufferRange()).toEqual([[3, 16], [6, 20]]);

          editor.selectUp(2);
          expect(selection1.getBufferRange()).toEqual([[0, 9], [1, 12]]);
          expect(selection2.getBufferRange()).toEqual([[3, 16], [4, 20]]);
        });
      });
    });

    describe('.selectToBufferPosition(bufferPosition)', () => {
      it('expands the last selection to the given position', () => {
        editor.setSelectedBufferRange([[3, 0], [4, 5]]);
        editor.addCursorAtBufferPosition([5, 6]);
        editor.selectToBufferPosition([6, 2]);

        const selections = editor.getSelections();
        expect(selections.length).toBe(2);
        const [selection1, selection2] = selections;
        expect(selection1.getBufferRange()).toEqual([[3, 0], [4, 5]]);
        expect(selection2.getBufferRange()).toEqual([[5, 6], [6, 2]]);
      });
    });

    describe('.selectToScreenPosition(screenPosition)', () => {
      it('expands the last selection to the given position', () => {
        editor.setSelectedBufferRange([[3, 0], [4, 5]]);
        editor.addCursorAtScreenPosition([5, 6]);
        editor.selectToScreenPosition([6, 2]);

        const selections = editor.getSelections();
        expect(selections.length).toBe(2);
        const [selection1, selection2] = selections;
        expect(selection1.getScreenRange()).toEqual([[3, 0], [4, 5]]);
        expect(selection2.getScreenRange()).toEqual([[5, 6], [6, 2]]);
      });

      describe('when selecting with an initial screen range', () => {
        it('switches the direction of the selection when selecting to positions before/after the start of the initial range', () => {
          editor.setCursorScreenPosition([5, 10]);
          editor.selectWordsContainingCursors();
          editor.selectToScreenPosition([3, 0]);
          expect(editor.getLastSelection().isReversed()).toBe(true);
          editor.selectToScreenPosition([9, 0]);
          expect(editor.getLastSelection().isReversed()).toBe(false);
        });
      });
    });

    describe('.selectToBeginningOfNextParagraph()', () => {
      it('selects from the cursor to first line of the next paragraph', () => {
        editor.setSelectedBufferRange([[3, 0], [4, 5]]);
        editor.addCursorAtScreenPosition([5, 6]);
        editor.selectToScreenPosition([6, 2]);

        editor.selectToBeginningOfNextParagraph();

        const selections = editor.getSelections();
        expect(selections.length).toBe(1);
        expect(selections[0].getScreenRange()).toEqual([[3, 0], [10, 0]]);
      });
    });

    describe('.selectToBeginningOfPreviousParagraph()', () => {
      it('selects from the cursor to the first line of the previous paragraph', () => {
        editor.setSelectedBufferRange([[3, 0], [4, 5]]);
        editor.addCursorAtScreenPosition([5, 6]);
        editor.selectToScreenPosition([6, 2]);

        editor.selectToBeginningOfPreviousParagraph();

        const selections = editor.getSelections();
        expect(selections.length).toBe(1);
        expect(selections[0].getScreenRange()).toEqual([[0, 0], [5, 6]]);
      });

      it('merges selections if they intersect, maintaining the directionality of the last selection', () => {
        editor.setCursorScreenPosition([4, 10]);
        editor.selectToScreenPosition([5, 27]);
        editor.addCursorAtScreenPosition([3, 10]);
        editor.selectToScreenPosition([6, 27]);

        let selections = editor.getSelections();
        expect(selections.length).toBe(1);
        let [selection1] = selections;
        expect(selection1.getScreenRange()).toEqual([[3, 10], [6, 27]]);
        expect(selection1.isReversed()).toBeFalsy();

        editor.addCursorAtScreenPosition([7, 4]);
        editor.selectToScreenPosition([4, 11]);

        selections = editor.getSelections();
        expect(selections.length).toBe(1);
        [selection1] = selections;
        expect(selection1.getScreenRange()).toEqual([[3, 10], [7, 4]]);
        expect(selection1.isReversed()).toBeTruthy();
      });
    });

    describe('.selectToTop()', () => {
      it('selects text from cursor position to the top of the buffer', () => {
        editor.setCursorScreenPosition([11, 2]);
        editor.addCursorAtScreenPosition([10, 0]);
        editor.selectToTop();
        expect(editor.getCursors().length).toBe(1);
        expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
        expect(editor.getLastSelection().getBufferRange()).toEqual([
          [0, 0],
          [11, 2]
        ]);
        expect(editor.getLastSelection().isReversed()).toBeTruthy();
      });
    });

    describe('.selectToBottom()', () => {
      it('selects text from cursor position to the bottom of the buffer', () => {
        editor.setCursorScreenPosition([10, 0]);
        editor.addCursorAtScreenPosition([9, 3]);
        editor.selectToBottom();
        expect(editor.getCursors().length).toBe(1);
        expect(editor.getCursorBufferPosition()).toEqual([12, 2]);
        expect(editor.getLastSelection().getBufferRange()).toEqual([
          [9, 3],
          [12, 2]
        ]);
        expect(editor.getLastSelection().isReversed()).toBeFalsy();
      });
    });

    describe('.selectAll()', () => {
      it('selects the entire buffer', () => {
        editor.selectAll();
        expect(editor.getLastSelection().getBufferRange()).toEqual(
          buffer.getRange()
        );
      });
    });

    describe('.selectToBeginningOfLine()', () => {
      it('selects text from cursor position to beginning of line', () => {
        editor.setCursorScreenPosition([12, 2]);
        editor.addCursorAtScreenPosition([11, 3]);

        editor.selectToBeginningOfLine();

        expect(editor.getCursors().length).toBe(2);
        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([12, 0]);
        expect(cursor2.getBufferPosition()).toEqual([11, 0]);

        expect(editor.getSelections().length).toBe(2);
        const [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[12, 0], [12, 2]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[11, 0], [11, 3]]);
        expect(selection2.isReversed()).toBeTruthy();
      });
    });

    describe('.selectToEndOfLine()', () => {
      it('selects text from cursor position to end of line', () => {
        editor.setCursorScreenPosition([12, 0]);
        editor.addCursorAtScreenPosition([11, 3]);

        editor.selectToEndOfLine();

        expect(editor.getCursors().length).toBe(2);
        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([12, 2]);
        expect(cursor2.getBufferPosition()).toEqual([11, 44]);

        expect(editor.getSelections().length).toBe(2);
        const [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[12, 0], [12, 2]]);
        expect(selection1.isReversed()).toBeFalsy();
        expect(selection2.getBufferRange()).toEqual([[11, 3], [11, 44]]);
        expect(selection2.isReversed()).toBeFalsy();
      });
    });

    describe('.selectLinesContainingCursors()', () => {
      it('selects to the entire line (including newlines) at given row', () => {
        editor.setCursorScreenPosition([1, 2]);
        editor.selectLinesContainingCursors();
        expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [2, 0]]);
        expect(editor.getSelectedText()).toBe(
          '  var sort = function(items) {\n'
        );

        editor.setCursorScreenPosition([12, 2]);
        editor.selectLinesContainingCursors();
        expect(editor.getSelectedBufferRange()).toEqual([[12, 0], [12, 2]]);

        editor.setCursorBufferPosition([0, 2]);
        editor.selectLinesContainingCursors();
        editor.selectLinesContainingCursors();
        expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [2, 0]]);
      });

      describe('when the selection spans multiple row', () => {
        it('selects from the beginning of the first line to the last line', () => {
          selection = editor.getLastSelection();
          selection.setBufferRange([[1, 10], [3, 20]]);
          editor.selectLinesContainingCursors();
          expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [4, 0]]);
        });
      });
    });

    describe('.selectToBeginningOfWord()', () => {
      it('selects text from cursor position to beginning of word', () => {
        editor.setCursorScreenPosition([0, 13]);
        editor.addCursorAtScreenPosition([3, 49]);

        editor.selectToBeginningOfWord();

        expect(editor.getCursors().length).toBe(2);
        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([0, 4]);
        expect(cursor2.getBufferPosition()).toEqual([3, 47]);

        expect(editor.getSelections().length).toBe(2);
        const [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 4], [0, 13]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[3, 47], [3, 49]]);
        expect(selection2.isReversed()).toBeTruthy();
      });
    });

    describe('.selectToEndOfWord()', () => {
      it('selects text from cursor position to end of word', () => {
        editor.setCursorScreenPosition([0, 4]);
        editor.addCursorAtScreenPosition([3, 48]);

        editor.selectToEndOfWord();

        expect(editor.getCursors().length).toBe(2);
        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([0, 13]);
        expect(cursor2.getBufferPosition()).toEqual([3, 50]);

        expect(editor.getSelections().length).toBe(2);
        const [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 4], [0, 13]]);
        expect(selection1.isReversed()).toBeFalsy();
        expect(selection2.getBufferRange()).toEqual([[3, 48], [3, 50]]);
        expect(selection2.isReversed()).toBeFalsy();
      });
    });

    describe('.selectToBeginningOfNextWord()', () => {
      it('selects text from cursor position to beginning of next word', () => {
        editor.setCursorScreenPosition([0, 4]);
        editor.addCursorAtScreenPosition([3, 48]);

        editor.selectToBeginningOfNextWord();

        expect(editor.getCursors().length).toBe(2);
        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([0, 14]);
        expect(cursor2.getBufferPosition()).toEqual([3, 51]);

        expect(editor.getSelections().length).toBe(2);
        const [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 4], [0, 14]]);
        expect(selection1.isReversed()).toBeFalsy();
        expect(selection2.getBufferRange()).toEqual([[3, 48], [3, 51]]);
        expect(selection2.isReversed()).toBeFalsy();
      });
    });

    describe('.selectToPreviousWordBoundary()', () => {
      it('select to the previous word boundary', () => {
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([2, 0]);
        editor.addCursorAtBufferPosition([3, 4]);
        editor.addCursorAtBufferPosition([3, 14]);

        editor.selectToPreviousWordBoundary();

        expect(editor.getSelections().length).toBe(4);
        const [
          selection1,
          selection2,
          selection3,
          selection4
        ] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 8], [0, 4]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[2, 0], [1, 30]]);
        expect(selection2.isReversed()).toBeTruthy();
        expect(selection3.getBufferRange()).toEqual([[3, 4], [3, 0]]);
        expect(selection3.isReversed()).toBeTruthy();
        expect(selection4.getBufferRange()).toEqual([[3, 14], [3, 13]]);
        expect(selection4.isReversed()).toBeTruthy();
      });
    });

    describe('.selectToNextWordBoundary()', () => {
      it('select to the next word boundary', () => {
        editor.setCursorBufferPosition([0, 8]);
        editor.addCursorAtBufferPosition([2, 40]);
        editor.addCursorAtBufferPosition([4, 0]);
        editor.addCursorAtBufferPosition([3, 30]);

        editor.selectToNextWordBoundary();

        expect(editor.getSelections().length).toBe(4);
        const [
          selection1,
          selection2,
          selection3,
          selection4
        ] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 8], [0, 13]]);
        expect(selection1.isReversed()).toBeFalsy();
        expect(selection2.getBufferRange()).toEqual([[2, 40], [3, 0]]);
        expect(selection2.isReversed()).toBeFalsy();
        expect(selection3.getBufferRange()).toEqual([[4, 0], [4, 4]]);
        expect(selection3.isReversed()).toBeFalsy();
        expect(selection4.getBufferRange()).toEqual([[3, 30], [3, 31]]);
        expect(selection4.isReversed()).toBeFalsy();
      });
    });

    describe('.selectToPreviousSubwordBoundary', () => {
      it('selects subwords', () => {
        editor.setText('');
        editor.insertText('_word\n');
        editor.insertText(' getPreviousWord\n');
        editor.insertText('e, => \n');
        editor.insertText(' 88 \n');
        editor.setCursorBufferPosition([0, 5]);
        editor.addCursorAtBufferPosition([1, 7]);
        editor.addCursorAtBufferPosition([2, 5]);
        editor.addCursorAtBufferPosition([3, 3]);
        const [
          selection1,
          selection2,
          selection3,
          selection4
        ] = editor.getSelections();

        editor.selectToPreviousSubwordBoundary();
        expect(selection1.getBufferRange()).toEqual([[0, 1], [0, 5]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[1, 4], [1, 7]]);
        expect(selection2.isReversed()).toBeTruthy();
        expect(selection3.getBufferRange()).toEqual([[2, 3], [2, 5]]);
        expect(selection3.isReversed()).toBeTruthy();
        expect(selection4.getBufferRange()).toEqual([[3, 1], [3, 3]]);
        expect(selection4.isReversed()).toBeTruthy();
      });
    });

    describe('.selectToNextSubwordBoundary', () => {
      it('selects subwords', () => {
        editor.setText('');
        editor.insertText('word_\n');
        editor.insertText('getPreviousWord\n');
        editor.insertText('e, => \n');
        editor.insertText(' 88 \n');
        editor.setCursorBufferPosition([0, 1]);
        editor.addCursorAtBufferPosition([1, 7]);
        editor.addCursorAtBufferPosition([2, 2]);
        editor.addCursorAtBufferPosition([3, 1]);
        const [
          selection1,
          selection2,
          selection3,
          selection4
        ] = editor.getSelections();

        editor.selectToNextSubwordBoundary();
        expect(selection1.getBufferRange()).toEqual([[0, 1], [0, 4]]);
        expect(selection1.isReversed()).toBeFalsy();
        expect(selection2.getBufferRange()).toEqual([[1, 7], [1, 11]]);
        expect(selection2.isReversed()).toBeFalsy();
        expect(selection3.getBufferRange()).toEqual([[2, 2], [2, 5]]);
        expect(selection3.isReversed()).toBeFalsy();
        expect(selection4.getBufferRange()).toEqual([[3, 1], [3, 3]]);
        expect(selection4.isReversed()).toBeFalsy();
      });
    });

    describe('.deleteToBeginningOfSubword', () => {
      it('deletes subwords', () => {
        editor.setText('');
        editor.insertText('_word\n');
        editor.insertText(' getPreviousWord\n');
        editor.insertText('e, => \n');
        editor.insertText(' 88 \n');
        editor.setCursorBufferPosition([0, 5]);
        editor.addCursorAtBufferPosition([1, 7]);
        editor.addCursorAtBufferPosition([2, 5]);
        editor.addCursorAtBufferPosition([3, 3]);
        const [cursor1, cursor2, cursor3, cursor4] = editor.getCursors();

        editor.deleteToBeginningOfSubword();
        expect(buffer.lineForRow(0)).toBe('_');
        expect(buffer.lineForRow(1)).toBe(' getviousWord');
        expect(buffer.lineForRow(2)).toBe('e,  ');
        expect(buffer.lineForRow(3)).toBe('  ');
        expect(cursor1.getBufferPosition()).toEqual([0, 1]);
        expect(cursor2.getBufferPosition()).toEqual([1, 4]);
        expect(cursor3.getBufferPosition()).toEqual([2, 3]);
        expect(cursor4.getBufferPosition()).toEqual([3, 1]);

        editor.deleteToBeginningOfSubword();
        expect(buffer.lineForRow(0)).toBe('');
        expect(buffer.lineForRow(1)).toBe(' viousWord');
        expect(buffer.lineForRow(2)).toBe('e ');
        expect(buffer.lineForRow(3)).toBe(' ');
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor2.getBufferPosition()).toEqual([1, 1]);
        expect(cursor3.getBufferPosition()).toEqual([2, 1]);
        expect(cursor4.getBufferPosition()).toEqual([3, 0]);

        editor.deleteToBeginningOfSubword();
        expect(buffer.lineForRow(0)).toBe('');
        expect(buffer.lineForRow(1)).toBe('viousWord');
        expect(buffer.lineForRow(2)).toBe('  ');
        expect(buffer.lineForRow(3)).toBe('');
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor2.getBufferPosition()).toEqual([1, 0]);
        expect(cursor3.getBufferPosition()).toEqual([2, 0]);
        expect(cursor4.getBufferPosition()).toEqual([2, 1]);
      });
    });

    describe('.deleteToEndOfSubword', () => {
      it('deletes subwords', () => {
        editor.setText('');
        editor.insertText('word_\n');
        editor.insertText('getPreviousWord \n');
        editor.insertText('e, => \n');
        editor.insertText(' 88 \n');
        editor.setCursorBufferPosition([0, 0]);
        editor.addCursorAtBufferPosition([1, 0]);
        editor.addCursorAtBufferPosition([2, 2]);
        editor.addCursorAtBufferPosition([3, 0]);
        const [cursor1, cursor2, cursor3, cursor4] = editor.getCursors();

        editor.deleteToEndOfSubword();
        expect(buffer.lineForRow(0)).toBe('_');
        expect(buffer.lineForRow(1)).toBe('PreviousWord ');
        expect(buffer.lineForRow(2)).toBe('e, ');
        expect(buffer.lineForRow(3)).toBe('88 ');
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor2.getBufferPosition()).toEqual([1, 0]);
        expect(cursor3.getBufferPosition()).toEqual([2, 2]);
        expect(cursor4.getBufferPosition()).toEqual([3, 0]);

        editor.deleteToEndOfSubword();
        expect(buffer.lineForRow(0)).toBe('');
        expect(buffer.lineForRow(1)).toBe('Word ');
        expect(buffer.lineForRow(2)).toBe('e,');
        expect(buffer.lineForRow(3)).toBe(' ');
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor2.getBufferPosition()).toEqual([1, 0]);
        expect(cursor3.getBufferPosition()).toEqual([2, 2]);
        expect(cursor4.getBufferPosition()).toEqual([3, 0]);
      });
    });

    describe('.selectWordsContainingCursors()', () => {
      describe('when the cursor is inside a word', () => {
        it('selects the entire word', () => {
          editor.setCursorScreenPosition([0, 8]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedText()).toBe('quicksort');
        });
      });

      describe('when the cursor is between two words', () => {
        it('selects the word the cursor is on', () => {
          editor.setCursorBufferPosition([0, 4]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedText()).toBe('quicksort');

          editor.setCursorBufferPosition([0, 3]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedText()).toBe('var');

          editor.setCursorBufferPosition([1, 22]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedText()).toBe('items');
        });
      });

      describe('when the cursor is inside a region of whitespace', () => {
        it('selects the whitespace region', () => {
          editor.setCursorScreenPosition([5, 2]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedBufferRange()).toEqual([[5, 0], [5, 6]]);

          editor.setCursorScreenPosition([5, 0]);
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedBufferRange()).toEqual([[5, 0], [5, 6]]);
        });
      });

      describe('when the cursor is at the end of the text', () => {
        it('select the previous word', () => {
          editor.buffer.append('word');
          editor.moveToBottom();
          editor.selectWordsContainingCursors();
          expect(editor.getSelectedBufferRange()).toEqual([[12, 2], [12, 6]]);
        });
      });

      it("selects words based on the non-word characters configured at the cursor's current scope", () => {
        editor.setText("one-one; 'two-two'; three-three");

        editor.setCursorBufferPosition([0, 1]);
        editor.addCursorAtBufferPosition([0, 12]);

        const scopeDescriptors = editor
          .getCursors()
          .map(c => c.getScopeDescriptor());
        expect(scopeDescriptors[0].getScopesArray()).toEqual(['source.js']);
        expect(scopeDescriptors[1].getScopesArray()).toEqual([
          'source.js',
          'string.quoted'
        ]);

        spyOn(
          editor.getBuffer().getLanguageMode(),
          'getNonWordCharacters'
        ).andCallFake(function(position) {
          const result = '/()"\':,.;<>~!@#$%^&*|+=[]{}`?';
          const scopes = this.scopeDescriptorForPosition(
            position
          ).getScopesArray();
          if (scopes.some(scope => scope.startsWith('string'))) {
            return result;
          } else {
            return result + '-';
          }
        });

        editor.selectWordsContainingCursors();

        expect(editor.getSelections()[0].getText()).toBe('one');
        expect(editor.getSelections()[1].getText()).toBe('two-two');
      });
    });

    describe('.selectToFirstCharacterOfLine()', () => {
      it("moves to the first character of the current line or the beginning of the line if it's already on the first character", () => {
        editor.setCursorScreenPosition([0, 5]);
        editor.addCursorAtScreenPosition([1, 7]);

        editor.selectToFirstCharacterOfLine();

        const [cursor1, cursor2] = editor.getCursors();
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor2.getBufferPosition()).toEqual([1, 2]);

        expect(editor.getSelections().length).toBe(2);
        let [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 0], [0, 5]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[1, 2], [1, 7]]);
        expect(selection2.isReversed()).toBeTruthy();

        editor.selectToFirstCharacterOfLine();
        [selection1, selection2] = editor.getSelections();
        expect(selection1.getBufferRange()).toEqual([[0, 0], [0, 5]]);
        expect(selection1.isReversed()).toBeTruthy();
        expect(selection2.getBufferRange()).toEqual([[1, 0], [1, 7]]);
        expect(selection2.isReversed()).toBeTruthy();
      });
    });

    describe('.setSelectedBufferRanges(ranges)', () => {
      it('clears existing selections and creates selections for each of the given ranges', () => {
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 2], [3, 3]],
          [[4, 4], [5, 5]]
        ]);

        editor.setSelectedBufferRanges([[[5, 5], [6, 6]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([[[5, 5], [6, 6]]]);
      });

      it('merges intersecting selections', () => {
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([[[2, 2], [5, 5]]]);
      });

      it('does not merge non-empty adjacent selections', () => {
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 3], [5, 5]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 2], [3, 3]],
          [[3, 3], [5, 5]]
        ]);
      });

      it('recycles existing selection instances', () => {
        selection = editor.getLastSelection();
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]]);

        const [selection1] = editor.getSelections();
        expect(selection1).toBe(selection);
        expect(selection1.getBufferRange()).toEqual([[2, 2], [3, 3]]);
      });

      describe("when the 'preserveFolds' option is false (the default)", () => {
        it("removes folds that contain one or both of the selection's end points", () => {
          editor.setSelectedBufferRange([[0, 0], [0, 0]]);
          editor.foldBufferRowRange(1, 4);
          editor.foldBufferRowRange(2, 3);
          editor.foldBufferRowRange(6, 8);
          editor.foldBufferRowRange(10, 11);

          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 6], [7, 7]]]);
          expect(editor.isFoldedAtScreenRow(1)).toBeFalsy();
          expect(editor.isFoldedAtScreenRow(2)).toBeFalsy();
          expect(editor.isFoldedAtScreenRow(6)).toBeFalsy();
          expect(editor.isFoldedAtScreenRow(10)).toBeTruthy();

          editor.setSelectedBufferRange([[10, 0], [12, 0]]);
          expect(editor.isFoldedAtScreenRow(10)).toBeTruthy();
        });
      });

      describe("when the 'preserveFolds' option is true", () => {
        it('does not remove folds that contain the selections', () => {
          editor.setSelectedBufferRange([[0, 0], [0, 0]]);
          editor.foldBufferRowRange(1, 4);
          editor.foldBufferRowRange(6, 8);
          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 0], [6, 1]]], {
            preserveFolds: true
          });
          expect(editor.isFoldedAtBufferRow(1)).toBeTruthy();
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
        });
      });
    });

    describe('.setSelectedScreenRanges(ranges)', () => {
      beforeEach(() => editor.foldBufferRow(4));

      it('clears existing selections and creates selections for each of the given ranges', () => {
        editor.setSelectedScreenRanges([[[3, 4], [3, 7]], [[5, 4], [5, 7]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 4], [3, 7]],
          [[8, 4], [8, 7]]
        ]);

        editor.setSelectedScreenRanges([[[6, 2], [6, 4]]]);
        expect(editor.getSelectedScreenRanges()).toEqual([[[6, 2], [6, 4]]]);
      });

      it('merges intersecting selections and unfolds the fold which contain them', () => {
        editor.foldBufferRow(0);

        // Use buffer ranges because only the first line is on screen
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]]);
        expect(editor.getSelectedBufferRanges()).toEqual([[[2, 2], [5, 5]]]);
      });

      it('recycles existing selection instances', () => {
        selection = editor.getLastSelection();
        editor.setSelectedScreenRanges([[[2, 2], [3, 4]], [[4, 4], [5, 5]]]);

        const [selection1] = editor.getSelections();
        expect(selection1).toBe(selection);
        expect(selection1.getScreenRange()).toEqual([[2, 2], [3, 4]]);
      });
    });

    describe('.selectMarker(marker)', () => {
      describe('if the marker is valid', () => {
        it("selects the marker's range and returns the selected range", () => {
          const marker = editor.markBufferRange([[0, 1], [3, 3]]);
          expect(editor.selectMarker(marker)).toEqual([[0, 1], [3, 3]]);
          expect(editor.getSelectedBufferRange()).toEqual([[0, 1], [3, 3]]);
        });
      });

      describe('if the marker is invalid', () => {
        it('does not change the selection and returns a falsy value', () => {
          const marker = editor.markBufferRange([[0, 1], [3, 3]]);
          marker.destroy();
          expect(editor.selectMarker(marker)).toBeFalsy();
          expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 0]]);
        });
      });
    });

    describe('.addSelectionForBufferRange(bufferRange)', () => {
      it('adds a selection for the specified buffer range', () => {
        editor.addSelectionForBufferRange([[3, 4], [5, 6]]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 4], [5, 6]]
        ]);
      });
    });

    describe('.addSelectionBelow()', () => {
      describe('when the selection is non-empty', () => {
        it('selects the same region of the line below current selections if possible', () => {
          editor.setSelectedBufferRange([[3, 16], [3, 21]]);
          editor.addSelectionForBufferRange([[3, 25], [3, 34]]);
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 16], [3, 21]],
            [[3, 25], [3, 34]],
            [[4, 16], [4, 21]],
            [[4, 25], [4, 29]]
          ]);
        });

        it('skips lines that are too short to create a non-empty selection', () => {
          editor.setSelectedBufferRange([[3, 31], [3, 38]]);
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 31], [3, 38]],
            [[6, 31], [6, 38]]
          ]);
        });

        it("honors the original selection's range (goal range) when adding across shorter lines", () => {
          editor.setSelectedBufferRange([[3, 22], [3, 38]]);
          editor.addSelectionBelow();
          editor.addSelectionBelow();
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 22], [3, 38]],
            [[4, 22], [4, 29]],
            [[5, 22], [5, 30]],
            [[6, 22], [6, 38]]
          ]);
        });

        it('clears selection goal ranges when the selection changes', () => {
          editor.setSelectedBufferRange([[3, 22], [3, 38]]);
          editor.addSelectionBelow();
          editor.selectLeft();
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 22], [3, 37]],
            [[4, 22], [4, 29]],
            [[5, 22], [5, 28]]
          ]);

          // goal range from previous add selection is honored next time
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 22], [3, 37]],
            [[4, 22], [4, 29]],
            [[5, 22], [5, 30]], // select to end of line 5 because line 4's goal range was reset by line 3 previously
            [[6, 22], [6, 28]]
          ]);
        });

        it('can add selections to soft-wrapped line segments', () => {
          editor.setSoftWrapped(true);
          editor.setEditorWidthInChars(40);
          editor.setDefaultCharWidth(1);

          editor.setSelectedScreenRange([[3, 10], [3, 15]]);
          editor.addSelectionBelow();
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[3, 10], [3, 15]],
            [[4, 10], [4, 15]]
          ]);
        });

        it('takes atomic tokens into account', async () => {
          editor = await atom.workspace.open(
            'sample-with-tabs-and-leading-comment.coffee',
            { autoIndent: false }
          );
          editor.setSelectedBufferRange([[2, 1], [2, 3]]);
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[2, 1], [2, 3]],
            [[3, 1], [3, 2]]
          ]);
        });
      });

      describe('when the selection is empty', () => {
        describe('when lines are soft-wrapped', () => {
          beforeEach(() => {
            editor.setSoftWrapped(true);
            editor.setDefaultCharWidth(1);
            editor.setEditorWidthInChars(40);
          });

          it('skips soft-wrap indentation tokens', () => {
            editor.setCursorScreenPosition([3, 0]);
            editor.addSelectionBelow();

            expect(editor.getSelectedScreenRanges()).toEqual([
              [[3, 0], [3, 0]],
              [[4, 4], [4, 4]]
            ]);
          });

          it("does not skip them if they're shorter than the current column", () => {
            editor.setCursorScreenPosition([3, 37]);
            editor.addSelectionBelow();

            expect(editor.getSelectedScreenRanges()).toEqual([
              [[3, 37], [3, 37]],
              [[4, 26], [4, 26]]
            ]);
          });
        });

        it('does not skip lines that are shorter than the current column', () => {
          editor.setCursorBufferPosition([3, 36]);
          editor.addSelectionBelow();
          editor.addSelectionBelow();
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 36], [3, 36]],
            [[4, 29], [4, 29]],
            [[5, 30], [5, 30]],
            [[6, 36], [6, 36]]
          ]);
        });

        it('skips empty lines when the column is non-zero', () => {
          editor.setCursorBufferPosition([9, 4]);
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[9, 4], [9, 4]],
            [[11, 4], [11, 4]]
          ]);
        });

        it('does not skip empty lines when the column is zero', () => {
          editor.setCursorBufferPosition([9, 0]);
          editor.addSelectionBelow();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[9, 0], [9, 0]],
            [[10, 0], [10, 0]]
          ]);
        });
      });

      it('does not create a new selection if it would be fully contained within another selection', () => {
        editor.setText('abc\ndef\nghi\njkl\nmno');
        editor.setCursorBufferPosition([0, 1]);

        let addedSelectionCount = 0;
        editor.onDidAddSelection(() => {
          addedSelectionCount++;
        });

        editor.addSelectionBelow();
        editor.addSelectionBelow();
        editor.addSelectionBelow();
        expect(addedSelectionCount).toBe(3);
      });
    });

    describe('.addSelectionAbove()', () => {
      describe('when the selection is non-empty', () => {
        it('selects the same region of the line above current selections if possible', () => {
          editor.setSelectedBufferRange([[3, 16], [3, 21]]);
          editor.addSelectionForBufferRange([[3, 37], [3, 44]]);
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 16], [3, 21]],
            [[3, 37], [3, 44]],
            [[2, 16], [2, 21]],
            [[2, 37], [2, 40]]
          ]);
        });

        it('skips lines that are too short to create a non-empty selection', () => {
          editor.setSelectedBufferRange([[6, 31], [6, 38]]);
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[6, 31], [6, 38]],
            [[3, 31], [3, 38]]
          ]);
        });

        it("honors the original selection's range (goal range) when adding across shorter lines", () => {
          editor.setSelectedBufferRange([[6, 22], [6, 38]]);
          editor.addSelectionAbove();
          editor.addSelectionAbove();
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[6, 22], [6, 38]],
            [[5, 22], [5, 30]],
            [[4, 22], [4, 29]],
            [[3, 22], [3, 38]]
          ]);
        });

        it('can add selections to soft-wrapped line segments', () => {
          editor.setSoftWrapped(true);
          editor.setDefaultCharWidth(1);
          editor.setEditorWidthInChars(40);

          editor.setSelectedScreenRange([[4, 10], [4, 15]]);
          editor.addSelectionAbove();
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[4, 10], [4, 15]],
            [[3, 10], [3, 15]]
          ]);
        });

        it('takes atomic tokens into account', async () => {
          editor = await atom.workspace.open(
            'sample-with-tabs-and-leading-comment.coffee',
            { autoIndent: false }
          );
          editor.setSelectedBufferRange([[3, 1], [3, 2]]);
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 1], [3, 2]],
            [[2, 1], [2, 3]]
          ]);
        });
      });

      describe('when the selection is empty', () => {
        describe('when lines are soft-wrapped', () => {
          beforeEach(() => {
            editor.setSoftWrapped(true);
            editor.setDefaultCharWidth(1);
            editor.setEditorWidthInChars(40);
          });

          it('skips soft-wrap indentation tokens', () => {
            editor.setCursorScreenPosition([5, 0]);
            editor.addSelectionAbove();

            expect(editor.getSelectedScreenRanges()).toEqual([
              [[5, 0], [5, 0]],
              [[4, 4], [4, 4]]
            ]);
          });

          it("does not skip them if they're shorter than the current column", () => {
            editor.setCursorScreenPosition([5, 29]);
            editor.addSelectionAbove();

            expect(editor.getSelectedScreenRanges()).toEqual([
              [[5, 29], [5, 29]],
              [[4, 26], [4, 26]]
            ]);
          });
        });

        it('does not skip lines that are shorter than the current column', () => {
          editor.setCursorBufferPosition([6, 36]);
          editor.addSelectionAbove();
          editor.addSelectionAbove();
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[6, 36], [6, 36]],
            [[5, 30], [5, 30]],
            [[4, 29], [4, 29]],
            [[3, 36], [3, 36]]
          ]);
        });

        it('skips empty lines when the column is non-zero', () => {
          editor.setCursorBufferPosition([11, 4]);
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[11, 4], [11, 4]],
            [[9, 4], [9, 4]]
          ]);
        });

        it('does not skip empty lines when the column is zero', () => {
          editor.setCursorBufferPosition([10, 0]);
          editor.addSelectionAbove();
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[10, 0], [10, 0]],
            [[9, 0], [9, 0]]
          ]);
        });
      });

      it('does not create a new selection if it would be fully contained within another selection', () => {
        editor.setText('abc\ndef\nghi\njkl\nmno');
        editor.setCursorBufferPosition([4, 1]);

        let addedSelectionCount = 0;
        editor.onDidAddSelection(() => {
          addedSelectionCount++;
        });

        editor.addSelectionAbove();
        editor.addSelectionAbove();
        editor.addSelectionAbove();
        expect(addedSelectionCount).toBe(3);
      });
    });

    describe('.splitSelectionsIntoLines()', () => {
      it('splits all multi-line selections into one selection per line', () => {
        editor.setSelectedBufferRange([[0, 3], [2, 4]]);
        editor.splitSelectionsIntoLines();
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 29]],
          [[1, 0], [1, 30]],
          [[2, 0], [2, 4]]
        ]);

        editor.setSelectedBufferRange([[0, 3], [1, 10]]);
        editor.splitSelectionsIntoLines();
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 29]],
          [[1, 0], [1, 10]]
        ]);

        editor.setSelectedBufferRange([[0, 0], [0, 3]]);
        editor.splitSelectionsIntoLines();
        expect(editor.getSelectedBufferRanges()).toEqual([[[0, 0], [0, 3]]]);
      });
    });

    describe('::consolidateSelections()', () => {
      const makeMultipleSelections = () => {
        selection.setBufferRange([[3, 16], [3, 21]]);
        const selection2 = editor.addSelectionForBufferRange([
          [3, 25],
          [3, 34]
        ]);
        const selection3 = editor.addSelectionForBufferRange([[8, 4], [8, 10]]);
        const selection4 = editor.addSelectionForBufferRange([[1, 6], [1, 10]]);
        expect(editor.getSelections()).toEqual([
          selection,
          selection2,
          selection3,
          selection4
        ]);
        return [selection, selection2, selection3, selection4];
      };

      it('destroys all selections but the oldest selection and autoscrolls to it, returning true if any selections were destroyed', () => {
        const [selection1] = makeMultipleSelections();

        const autoscrollEvents = [];
        editor.onDidRequestAutoscroll(event => autoscrollEvents.push(event));

        expect(editor.consolidateSelections()).toBeTruthy();
        expect(editor.getSelections()).toEqual([selection1]);
        expect(selection1.isEmpty()).toBeFalsy();
        expect(editor.consolidateSelections()).toBeFalsy();
        expect(editor.getSelections()).toEqual([selection1]);

        expect(autoscrollEvents).toEqual([
          {
            screenRange: selection1.getScreenRange(),
            options: { center: true, reversed: false }
          }
        ]);
      });
    });

    describe('when the cursor is moved while there is a selection', () => {
      const makeSelection = () => selection.setBufferRange([[1, 2], [1, 5]]);

      it('clears the selection', () => {
        makeSelection();
        editor.moveDown();
        expect(selection.isEmpty()).toBeTruthy();

        makeSelection();
        editor.moveUp();
        expect(selection.isEmpty()).toBeTruthy();

        makeSelection();
        editor.moveLeft();
        expect(selection.isEmpty()).toBeTruthy();

        makeSelection();
        editor.moveRight();
        expect(selection.isEmpty()).toBeTruthy();

        makeSelection();
        editor.setCursorScreenPosition([3, 3]);
        expect(selection.isEmpty()).toBeTruthy();
      });
    });

    it('does not share selections between different edit sessions for the same buffer', async () => {
      atom.workspace.getActivePane().splitRight();
      const editor2 = await atom.workspace.open(editor.getPath());

      expect(editor2.getText()).toBe(editor.getText());
      editor.setSelectedBufferRanges([[[1, 2], [3, 4]], [[5, 6], [7, 8]]]);
      editor2.setSelectedBufferRanges([[[8, 7], [6, 5]], [[4, 3], [2, 1]]]);
      expect(editor2.getSelectedBufferRanges()).not.toEqual(
        editor.getSelectedBufferRanges()
      );
    });
  });

  describe('buffer manipulation', () => {
    describe('.moveLineUp', () => {
      it('moves the line under the cursor up', () => {
        editor.setCursorBufferPosition([1, 0]);
        editor.moveLineUp();
        expect(editor.getTextInBufferRange([[0, 0], [0, 30]])).toBe(
          '  var sort = function(items) {'
        );
        expect(editor.indentationForBufferRow(0)).toBe(1);
        expect(editor.indentationForBufferRow(1)).toBe(0);
      });

      it("updates the line's indentation when the the autoIndent setting is true", () => {
        editor.update({ autoIndent: true });
        editor.setCursorBufferPosition([1, 0]);
        editor.moveLineUp();
        expect(editor.indentationForBufferRow(0)).toBe(0);
        expect(editor.indentationForBufferRow(1)).toBe(0);
      });

      describe('when there is a single selection', () => {
        describe('when the selection spans a single line', () => {
          describe('when there is no fold in the preceeding row', () =>
            it('moves the line to the preceding row', () => {
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );

              editor.setSelectedBufferRange([[3, 2], [3, 9]]);
              editor.moveLineUp();

              expect(editor.getSelectedBufferRange()).toEqual([[2, 2], [2, 9]]);
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    if (items.length <= 1) return items;'
              );
            }));

          describe('when the cursor is at the beginning of a fold', () =>
            it('moves the line to the previous row without breaking the fold', () => {
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);
              editor.setSelectedBufferRange([[4, 2], [4, 9]], {
                preserveFolds: true
              });
              expect(editor.getSelectedBufferRange()).toEqual([[4, 2], [4, 9]]);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.moveLineUp();

              expect(editor.getSelectedBufferRange()).toEqual([[3, 2], [3, 9]]);
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );

              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
            }));

          describe('when the preceding row consists of folded code', () =>
            it('moves the line above the folded row and perseveres the correct folds', () => {
              expect(editor.lineTextForBufferRow(8)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
              expect(editor.lineTextForBufferRow(9)).toBe('  };');

              editor.foldBufferRowRange(4, 7);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.setSelectedBufferRange([[8, 0], [8, 4]]);
              editor.moveLineUp();

              expect(editor.getSelectedBufferRange()).toEqual([[4, 0], [4, 4]]);
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
              expect(editor.lineTextForBufferRow(5)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
            }));
        });

        describe('when the selection spans multiple lines', () => {
          it('moves the lines spanned by the selection to the preceding row', () => {
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.setSelectedBufferRange([[3, 2], [4, 9]]);
            editor.moveLineUp();

            expect(editor.getSelectedBufferRange()).toEqual([[2, 2], [3, 9]]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    if (items.length <= 1) return items;'
            );
          });

          describe("when the selection's end intersects a fold", () =>
            it('moves the lines to the previous row without breaking the fold', () => {
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);
              editor.setSelectedBufferRange([[3, 2], [4, 9]], {
                preserveFolds: true
              });

              expect(editor.isFoldedAtBufferRow(3)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.moveLineUp();

              expect(editor.getSelectedBufferRange()).toEqual([[2, 2], [3, 9]]);
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    if (items.length <= 1) return items;'
              );

              expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
            }));

          describe("when the selection's start intersects a fold", () =>
            it('moves the lines to the previous row without breaking the fold', () => {
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);
              editor.setSelectedBufferRange([[4, 2], [8, 9]], {
                preserveFolds: true
              });

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();

              editor.moveLineUp();

              expect(editor.getSelectedBufferRange()).toEqual([[3, 2], [7, 9]]);
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
              expect(editor.lineTextForBufferRow(8)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );

              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
            }));
        });

        describe('when the selection spans multiple lines, but ends at column 0', () => {
          it('does not move the last line of the selection', () => {
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.setSelectedBufferRange([[3, 2], [4, 0]]);
            editor.moveLineUp();

            expect(editor.getSelectedBufferRange()).toEqual([[2, 2], [3, 0]]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );
          });
        });

        describe('when the preceeding row is a folded row', () => {
          it('moves the lines spanned by the selection to the preceeding row, but preserves the folded code', () => {
            expect(editor.lineTextForBufferRow(8)).toBe(
              '    return sort(left).concat(pivot).concat(sort(right));'
            );
            expect(editor.lineTextForBufferRow(9)).toBe('  };');

            editor.foldBufferRowRange(4, 7);
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

            editor.setSelectedBufferRange([[8, 0], [9, 2]]);
            editor.moveLineUp();

            expect(editor.getSelectedBufferRange()).toEqual([[4, 0], [5, 2]]);
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    return sort(left).concat(pivot).concat(sort(right));'
            );
            expect(editor.lineTextForBufferRow(5)).toBe('  };');
            expect(editor.lineTextForBufferRow(6)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.isFoldedAtBufferRow(5)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(9)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(10)).toBeFalsy();
          });
        });
      });

      describe('when there are multiple selections', () => {
        describe('when all the selections span different lines', () => {
          describe('when there is no folds', () =>
            it('moves all lines that are spanned by a selection to the preceding row', () => {
              editor.setSelectedBufferRanges([
                [[1, 2], [1, 9]],
                [[3, 2], [3, 9]],
                [[5, 2], [5, 9]]
              ]);
              editor.moveLineUp();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[0, 2], [0, 9]],
                [[2, 2], [2, 9]],
                [[4, 2], [4, 9]]
              ]);
              expect(editor.lineTextForBufferRow(0)).toBe(
                '  var sort = function(items) {'
              );
              expect(editor.lineTextForBufferRow(1)).toBe(
                'var quicksort = function () {'
              );
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '      current = items.shift();'
              );
              expect(editor.lineTextForBufferRow(5)).toBe(
                '    while(items.length > 0) {'
              );
            }));

          describe('when one selection intersects a fold', () =>
            it('moves the lines to the previous row without breaking the fold', () => {
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);
              editor.setSelectedBufferRanges(
                [[[2, 2], [2, 9]], [[4, 2], [4, 9]]],
                { preserveFolds: true }
              );

              expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(3)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();

              editor.moveLineUp();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[1, 2], [1, 9]],
                [[3, 2], [3, 9]]
              ]);

              expect(editor.lineTextForBufferRow(1)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(2)).toBe(
                '  var sort = function(items) {'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );

              expect(editor.isFoldedAtBufferRow(1)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
            }));

          describe('when there is a fold', () =>
            it('moves all lines that spanned by a selection to preceding row, preserving all folds', () => {
              editor.foldBufferRowRange(4, 7);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.setSelectedBufferRanges([
                [[8, 0], [8, 3]],
                [[11, 0], [11, 5]]
              ]);
              editor.moveLineUp();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[4, 0], [4, 3]],
                [[10, 0], [10, 5]]
              ]);
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
              expect(editor.lineTextForBufferRow(10)).toBe(
                '  return sort(Array.apply(this, arguments));'
              );
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
            }));
        });

        describe('when there are many folds', () => {
          beforeEach(async () => {
            editor = await atom.workspace.open('sample-with-many-folds.js', {
              autoIndent: false
            });
          });

          describe('and many selections intersects folded rows', () =>
            it('moves and preserves all the folds', () => {
              editor.foldBufferRowRange(2, 4);
              editor.foldBufferRowRange(7, 9);

              editor.setSelectedBufferRanges(
                [[[1, 0], [5, 4]], [[7, 0], [7, 4]]],
                { preserveFolds: true }
              );

              editor.moveLineUp();

              expect(editor.lineTextForBufferRow(1)).toEqual('function f3() {');
              expect(editor.lineTextForBufferRow(4)).toEqual('6;');
              expect(editor.lineTextForBufferRow(5)).toEqual('1;');
              expect(editor.lineTextForBufferRow(6)).toEqual('function f8() {');
              expect(editor.lineTextForBufferRow(9)).toEqual('7;');

              expect(editor.isFoldedAtBufferRow(1)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(2)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeFalsy();

              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
            }));
        });

        describe('when some of the selections span the same lines', () => {
          it('moves lines that contain multiple selections correctly', () => {
            editor.setSelectedBufferRanges([
              [[3, 2], [3, 9]],
              [[3, 12], [3, 13]]
            ]);
            editor.moveLineUp();

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[2, 2], [2, 9]],
              [[2, 12], [2, 13]]
            ]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
          });
        });

        describe('when one of the selections spans line 0', () => {
          it("doesn't move any lines, since line 0 can't move", () => {
            editor.setSelectedBufferRanges([
              [[0, 2], [1, 9]],
              [[2, 2], [2, 9]],
              [[4, 2], [4, 9]]
            ]);

            editor.moveLineUp();

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[0, 2], [1, 9]],
              [[2, 2], [2, 9]],
              [[4, 2], [4, 9]]
            ]);
            expect(buffer.isModified()).toBe(false);
          });
        });

        describe('when one of the selections spans the last line, and it is empty', () => {
          it("doesn't move any lines, since the last line can't move", () => {
            buffer.append('\n');
            editor.setSelectedBufferRanges([
              [[0, 2], [1, 9]],
              [[2, 2], [2, 9]],
              [[13, 0], [13, 0]]
            ]);

            editor.moveLineUp();

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[0, 2], [1, 9]],
              [[2, 2], [2, 9]],
              [[13, 0], [13, 0]]
            ]);
          });
        });
      });
    });

    describe('.moveLineDown', () => {
      it('moves the line under the cursor down', () => {
        editor.setCursorBufferPosition([0, 0]);
        editor.moveLineDown();
        expect(editor.getTextInBufferRange([[1, 0], [1, 31]])).toBe(
          'var quicksort = function () {'
        );
        expect(editor.indentationForBufferRow(0)).toBe(1);
        expect(editor.indentationForBufferRow(1)).toBe(0);
      });

      it("updates the line's indentation when the editor.autoIndent setting is true", () => {
        editor.update({ autoIndent: true });
        editor.setCursorBufferPosition([0, 0]);
        editor.moveLineDown();
        expect(editor.indentationForBufferRow(0)).toBe(1);
        expect(editor.indentationForBufferRow(1)).toBe(2);
      });

      describe('when there is a single selection', () => {
        describe('when the selection spans a single line', () => {
          describe('when there is no fold in the following row', () =>
            it('moves the line to the following row', () => {
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );

              editor.setSelectedBufferRange([[2, 2], [2, 9]]);
              editor.moveLineDown();

              expect(editor.getSelectedBufferRange()).toEqual([[3, 2], [3, 9]]);
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    if (items.length <= 1) return items;'
              );
            }));

          describe('when the cursor is at the beginning of a fold', () =>
            it('moves the line to the following row without breaking the fold', () => {
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);
              editor.setSelectedBufferRange([[4, 2], [4, 9]], {
                preserveFolds: true
              });

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.moveLineDown();

              expect(editor.getSelectedBufferRange()).toEqual([[5, 2], [5, 9]]);
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
              expect(editor.lineTextForBufferRow(5)).toBe(
                '    while(items.length > 0) {'
              );

              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
            }));

          describe('when the following row is a folded row', () =>
            it('moves the line below the folded row and preserves the fold', () => {
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(items.length > 0) {'
              );

              editor.foldBufferRowRange(4, 7);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.setSelectedBufferRange([[3, 0], [3, 4]]);
              editor.moveLineDown();

              expect(editor.getSelectedBufferRange()).toEqual([[7, 0], [7, 4]]);
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();

              expect(editor.lineTextForBufferRow(7)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
            }));
        });

        describe('when the selection spans multiple lines', () => {
          it('moves the lines spanned by the selection to the following row', () => {
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.setSelectedBufferRange([[2, 2], [3, 9]]);
            editor.moveLineDown();

            expect(editor.getSelectedBufferRange()).toEqual([[3, 2], [4, 9]]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
          });
        });

        describe('when the selection spans multiple lines, but ends at column 0', () => {
          it('does not move the last line of the selection', () => {
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.setSelectedBufferRange([[2, 2], [3, 0]]);
            editor.moveLineDown();

            expect(editor.getSelectedBufferRange()).toEqual([[3, 2], [4, 0]]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );
          });
        });

        describe("when the selection's end intersects a fold", () => {
          it('moves the lines to the following row without breaking the fold', () => {
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.foldBufferRowRange(4, 7);
            editor.setSelectedBufferRange([[3, 2], [4, 9]], {
              preserveFolds: true
            });

            expect(editor.isFoldedAtBufferRow(3)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

            editor.moveLineDown();

            expect(editor.getSelectedBufferRange()).toEqual([[4, 2], [5, 9]]);
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    return sort(left).concat(pivot).concat(sort(right));'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(5)).toBe(
              '    while(items.length > 0) {'
            );

            expect(editor.isFoldedAtBufferRow(4)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
          });
        });

        describe("when the selection's start intersects a fold", () => {
          it('moves the lines to the following row without breaking the fold', () => {
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.foldBufferRowRange(4, 7);
            editor.setSelectedBufferRange([[4, 2], [8, 9]], {
              preserveFolds: true
            });

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();

            editor.moveLineDown();

            expect(editor.getSelectedBufferRange()).toEqual([[5, 2], [9, 9]]);
            expect(editor.lineTextForBufferRow(4)).toBe('  };');
            expect(editor.lineTextForBufferRow(5)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.lineTextForBufferRow(9)).toBe(
              '    return sort(left).concat(pivot).concat(sort(right));'
            );

            expect(editor.isFoldedAtBufferRow(4)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(10)).toBeFalsy();
          });
        });

        describe('when the following row is a folded row', () => {
          it('moves the lines spanned by the selection to the following row, but preserves the folded code', () => {
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );

            editor.foldBufferRowRange(4, 7);
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

            editor.setSelectedBufferRange([[2, 0], [3, 2]]);
            editor.moveLineDown();

            expect(editor.getSelectedBufferRange()).toEqual([[6, 0], [7, 2]]);
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.isFoldedAtBufferRow(1)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(2)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeFalsy();
            expect(editor.lineTextForBufferRow(6)).toBe(
              '    if (items.length <= 1) return items;'
            );
          });
        });

        describe('when the last line of selection does not end with a valid line ending', () => {
          it('appends line ending to last line and moves the lines spanned by the selection to the preceeding row', () => {
            expect(editor.lineTextForBufferRow(9)).toBe('  };');
            expect(editor.lineTextForBufferRow(10)).toBe('');
            expect(editor.lineTextForBufferRow(11)).toBe(
              '  return sort(Array.apply(this, arguments));'
            );
            expect(editor.lineTextForBufferRow(12)).toBe('};');

            editor.setSelectedBufferRange([[10, 0], [12, 2]]);
            editor.moveLineUp();

            expect(editor.getSelectedBufferRange()).toEqual([[9, 0], [11, 2]]);
            expect(editor.lineTextForBufferRow(9)).toBe('');
            expect(editor.lineTextForBufferRow(10)).toBe(
              '  return sort(Array.apply(this, arguments));'
            );
            expect(editor.lineTextForBufferRow(11)).toBe('};');
            expect(editor.lineTextForBufferRow(12)).toBe('  };');
          });
        });
      });

      describe('when there are multiple selections', () => {
        describe('when all the selections span different lines', () => {
          describe('when there is no folds', () =>
            it('moves all lines that are spanned by a selection to the following row', () => {
              editor.setSelectedBufferRanges([
                [[1, 2], [1, 9]],
                [[3, 2], [3, 9]],
                [[5, 2], [5, 9]]
              ]);
              editor.moveLineDown();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[6, 2], [6, 9]],
                [[4, 2], [4, 9]],
                [[2, 2], [2, 9]]
              ]);
              expect(editor.lineTextForBufferRow(1)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(2)).toBe(
                '  var sort = function(items) {'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(5)).toBe(
                '      current < pivot ? left.push(current) : right.push(current);'
              );
              expect(editor.lineTextForBufferRow(6)).toBe(
                '      current = items.shift();'
              );
            }));

          describe('when there are many folds', () => {
            beforeEach(async () => {
              editor = await atom.workspace.open('sample-with-many-folds.js', {
                autoIndent: false
              });
            });

            describe('and many selections intersects folded rows', () =>
              it('moves and preserves all the folds', () => {
                editor.foldBufferRowRange(2, 4);
                editor.foldBufferRowRange(7, 9);

                editor.setSelectedBufferRanges(
                  [[[2, 0], [2, 4]], [[6, 0], [10, 4]]],
                  { preserveFolds: true }
                );

                editor.moveLineDown();

                expect(editor.lineTextForBufferRow(2)).toEqual('6;');
                expect(editor.lineTextForBufferRow(3)).toEqual(
                  'function f3() {'
                );
                expect(editor.lineTextForBufferRow(6)).toEqual('12;');
                expect(editor.lineTextForBufferRow(7)).toEqual('7;');
                expect(editor.lineTextForBufferRow(8)).toEqual(
                  'function f8() {'
                );
                expect(editor.lineTextForBufferRow(11)).toEqual('11;');

                expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
                expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(6)).toBeFalsy();
                expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
                expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(9)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(10)).toBeTruthy();
                expect(editor.isFoldedAtBufferRow(11)).toBeFalsy();
              }));
          });

          describe('when there is a fold below one of the selected row', () =>
            it('moves all lines spanned by a selection to the following row, preserving the fold', () => {
              editor.foldBufferRowRange(4, 7);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.setSelectedBufferRanges([
                [[1, 2], [1, 6]],
                [[3, 0], [3, 4]],
                [[8, 0], [8, 3]]
              ]);
              editor.moveLineDown();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[9, 0], [9, 3]],
                [[7, 0], [7, 4]],
                [[2, 2], [2, 6]]
              ]);
              expect(editor.lineTextForBufferRow(2)).toBe(
                '  var sort = function(items) {'
              );
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy();
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(9)).toBe(
                '    return sort(left).concat(pivot).concat(sort(right));'
              );
            }));

          describe('when there is a fold below a group of multiple selections without any lines with no selection in-between', () =>
            it('moves all the lines below the fold, preserving the fold', () => {
              editor.foldBufferRowRange(4, 7);

              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();

              editor.setSelectedBufferRanges([
                [[2, 2], [2, 6]],
                [[3, 0], [3, 4]]
              ]);
              editor.moveLineDown();

              expect(editor.getSelectedBufferRanges()).toEqual([
                [[7, 0], [7, 4]],
                [[6, 2], [6, 6]]
              ]);
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.isFoldedAtBufferRow(2)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
              expect(editor.isFoldedAtBufferRow(6)).toBeFalsy();
              expect(editor.lineTextForBufferRow(6)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(7)).toBe(
                '    var pivot = items.shift(), current, left = [], right = [];'
              );
            }));
        });

        describe('when one selection intersects a fold', () => {
          it('moves the lines to the previous row without breaking the fold', () => {
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    while(items.length > 0) {'
            );

            editor.foldBufferRowRange(4, 7);
            editor.setSelectedBufferRanges(
              [[[2, 2], [2, 9]], [[4, 2], [4, 9]]],
              { preserveFolds: true }
            );

            expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(3)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();

            editor.moveLineDown();

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[5, 2], [5, 9]],
              [[3, 2], [3, 9]]
            ]);

            expect(editor.lineTextForBufferRow(2)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    return sort(left).concat(pivot).concat(sort(right));'
            );

            expect(editor.lineTextForBufferRow(5)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.lineTextForBufferRow(9)).toBe('  };');

            expect(editor.isFoldedAtBufferRow(2)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(3)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(4)).toBeFalsy();
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy();
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy();
          });
        });

        describe('when some of the selections span the same lines', () => {
          it('moves lines that contain multiple selections correctly', () => {
            editor.setSelectedBufferRanges([
              [[3, 2], [3, 9]],
              [[3, 12], [3, 13]]
            ]);
            editor.moveLineDown();

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[4, 12], [4, 13]],
              [[4, 2], [4, 9]]
            ]);
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    while(items.length > 0) {'
            );
          });
        });

        describe('when the selections are above a wrapped line', () => {
          beforeEach(() => {
            editor.setSoftWrapped(true);
            editor.setEditorWidthInChars(80);
            editor.setText(dedent`
              1
              2
              Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat.
              3
              4
            `);
          });

          it('moves the lines past the soft wrapped line', () => {
            editor.setSelectedBufferRanges([
              [[0, 0], [0, 0]],
              [[1, 0], [1, 0]]
            ]);

            editor.moveLineDown();

            expect(editor.lineTextForBufferRow(0)).not.toBe('2');
            expect(editor.lineTextForBufferRow(1)).toBe('1');
            expect(editor.lineTextForBufferRow(2)).toBe('2');
          });
        });
      });

      describe('when the line is the last buffer row', () => {
        it("doesn't move it", () => {
          editor.setText('abc\ndef');
          editor.setCursorBufferPosition([1, 0]);
          editor.moveLineDown();
          expect(editor.getText()).toBe('abc\ndef');
        });
      });
    });

    describe('.insertText(text)', () => {
      describe('when there is a single selection', () => {
        beforeEach(() => editor.setSelectedBufferRange([[1, 0], [1, 2]]));

        it('replaces the selection with the given text', () => {
          const range = editor.insertText('xxx');
          expect(range).toEqual([[[1, 0], [1, 3]]]);
          expect(buffer.lineForRow(1)).toBe('xxxvar sort = function(items) {');
        });
      });

      describe('when there are multiple empty selections', () => {
        describe('when the cursors are on the same line', () => {
          it("inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", () => {
            editor.setCursorScreenPosition([1, 2]);
            editor.addCursorAtScreenPosition([1, 5]);

            editor.insertText('xxx');

            expect(buffer.lineForRow(1)).toBe(
              '  xxxvarxxx sort = function(items) {'
            );
            const [cursor1, cursor2] = editor.getCursors();

            expect(cursor1.getBufferPosition()).toEqual([1, 5]);
            expect(cursor2.getBufferPosition()).toEqual([1, 11]);
          });
        });

        describe('when the cursors are on different lines', () => {
          it("inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", () => {
            editor.setCursorScreenPosition([1, 2]);
            editor.addCursorAtScreenPosition([2, 4]);

            editor.insertText('xxx');

            expect(buffer.lineForRow(1)).toBe(
              '  xxxvar sort = function(items) {'
            );
            expect(buffer.lineForRow(2)).toBe(
              '    xxxif (items.length <= 1) return items;'
            );
            const [cursor1, cursor2] = editor.getCursors();

            expect(cursor1.getBufferPosition()).toEqual([1, 5]);
            expect(cursor2.getBufferPosition()).toEqual([2, 7]);
          });
        });
      });

      describe('when there are multiple non-empty selections', () => {
        describe('when the selections are on the same line', () => {
          it('replaces each selection range with the inserted characters', () => {
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[0, 22], [0, 24]]
            ]);
            editor.insertText('x');

            const [cursor1, cursor2] = editor.getCursors();
            const [selection1, selection2] = editor.getSelections();

            expect(cursor1.getScreenPosition()).toEqual([0, 5]);
            expect(cursor2.getScreenPosition()).toEqual([0, 15]);
            expect(selection1.isEmpty()).toBeTruthy();
            expect(selection2.isEmpty()).toBeTruthy();

            expect(editor.lineTextForBufferRow(0)).toBe('var x = functix () {');
          });
        });

        describe('when the selections are on different lines', () => {
          it("replaces each selection with the given text, clears the selections, and places the cursor at the end of each selection's inserted text", () => {
            editor.setSelectedBufferRanges([
              [[1, 0], [1, 2]],
              [[2, 0], [2, 4]]
            ]);

            editor.insertText('xxx');

            expect(buffer.lineForRow(1)).toBe(
              'xxxvar sort = function(items) {'
            );
            expect(buffer.lineForRow(2)).toBe(
              'xxxif (items.length <= 1) return items;'
            );
            const [selection1, selection2] = editor.getSelections();

            expect(selection1.isEmpty()).toBeTruthy();
            expect(selection1.cursor.getBufferPosition()).toEqual([1, 3]);
            expect(selection2.isEmpty()).toBeTruthy();
            expect(selection2.cursor.getBufferPosition()).toEqual([2, 3]);
          });
        });
      });

      describe('when there is a selection that ends on a folded line', () => {
        it('destroys the selection', () => {
          editor.foldBufferRowRange(2, 4);
          editor.setSelectedBufferRange([[1, 0], [2, 0]]);
          editor.insertText('holy cow');
          expect(editor.isFoldedAtScreenRow(2)).toBeFalsy();
        });
      });

      describe('when there are ::onWillInsertText and ::onDidInsertText observers', () => {
        beforeEach(() => editor.setSelectedBufferRange([[1, 0], [1, 2]]));

        it('notifies the observers when inserting text', () => {
          const willInsertSpy = jasmine
            .createSpy()
            .andCallFake(() =>
              expect(buffer.lineForRow(1)).toBe(
                '  var sort = function(items) {'
              )
            );

          const didInsertSpy = jasmine
            .createSpy()
            .andCallFake(() =>
              expect(buffer.lineForRow(1)).toBe(
                'xxxvar sort = function(items) {'
              )
            );

          editor.onWillInsertText(willInsertSpy);
          editor.onDidInsertText(didInsertSpy);

          expect(editor.insertText('xxx')).toBeTruthy();
          expect(buffer.lineForRow(1)).toBe('xxxvar sort = function(items) {');

          expect(willInsertSpy).toHaveBeenCalled();
          expect(didInsertSpy).toHaveBeenCalled();

          let options = willInsertSpy.mostRecentCall.args[0];
          expect(options.text).toBe('xxx');
          expect(options.cancel).toBeDefined();

          options = didInsertSpy.mostRecentCall.args[0];
          expect(options.text).toBe('xxx');
        });

        it('cancels text insertion when an ::onWillInsertText observer calls cancel on an event', () => {
          const willInsertSpy = jasmine
            .createSpy()
            .andCallFake(({ cancel }) => cancel());

          const didInsertSpy = jasmine.createSpy();

          editor.onWillInsertText(willInsertSpy);
          editor.onDidInsertText(didInsertSpy);

          expect(editor.insertText('xxx')).toBe(false);
          expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');

          expect(willInsertSpy).toHaveBeenCalled();
          expect(didInsertSpy).not.toHaveBeenCalled();
        });
      });

      describe("when the undo option is set to 'skip'", () => {
        it('groups the change with the previous change for purposes of undo and redo', () => {
          editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[1, 0], [1, 0]]]);
          editor.insertText('x');
          editor.insertText('y', { undo: 'skip' });
          editor.undo();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
          expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');
        });
      });
    });

    describe('.insertNewline()', () => {
      describe('when there is a single cursor', () => {
        describe('when the cursor is at the beginning of a line', () => {
          it('inserts an empty line before it', () => {
            editor.setCursorScreenPosition({ row: 1, column: 0 });

            editor.insertNewline();

            expect(buffer.lineForRow(1)).toBe('');
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 2,
              column: 0
            });
          });
        });

        describe('when the cursor is in the middle of a line', () => {
          it('splits the current line to form a new line', () => {
            editor.setCursorScreenPosition({ row: 1, column: 6 });
            const originalLine = buffer.lineForRow(1);
            const lineBelowOriginalLine = buffer.lineForRow(2);

            editor.insertNewline();

            expect(buffer.lineForRow(1)).toBe(originalLine.slice(0, 6));
            expect(buffer.lineForRow(2)).toBe(originalLine.slice(6));
            expect(buffer.lineForRow(3)).toBe(lineBelowOriginalLine);
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 2,
              column: 0
            });
          });
        });

        describe('when the cursor is on the end of a line', () => {
          it('inserts an empty line after it', () => {
            editor.setCursorScreenPosition({
              row: 1,
              column: buffer.lineForRow(1).length
            });

            editor.insertNewline();

            expect(buffer.lineForRow(2)).toBe('');
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 2,
              column: 0
            });
          });
        });
      });

      describe('when there are multiple cursors', () => {
        describe('when the cursors are on the same line', () => {
          it('breaks the line at the cursor locations', () => {
            editor.setCursorScreenPosition([3, 13]);
            editor.addCursorAtScreenPosition([3, 38]);

            editor.insertNewline();

            expect(editor.lineTextForBufferRow(3)).toBe('    var pivot');
            expect(editor.lineTextForBufferRow(4)).toBe(
              ' = items.shift(), current'
            );
            expect(editor.lineTextForBufferRow(5)).toBe(
              ', left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(6)).toBe(
              '    while(items.length > 0) {'
            );

            const [cursor1, cursor2] = editor.getCursors();
            expect(cursor1.getBufferPosition()).toEqual([4, 0]);
            expect(cursor2.getBufferPosition()).toEqual([5, 0]);
          });
        });

        describe('when the cursors are on different lines', () => {
          it('inserts newlines at each cursor location', () => {
            editor.setCursorScreenPosition([3, 0]);
            editor.addCursorAtScreenPosition([6, 0]);

            editor.insertText('\n');
            expect(editor.lineTextForBufferRow(3)).toBe('');
            expect(editor.lineTextForBufferRow(4)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.lineTextForBufferRow(5)).toBe(
              '    while(items.length > 0) {'
            );
            expect(editor.lineTextForBufferRow(6)).toBe(
              '      current = items.shift();'
            );
            expect(editor.lineTextForBufferRow(7)).toBe('');
            expect(editor.lineTextForBufferRow(8)).toBe(
              '      current < pivot ? left.push(current) : right.push(current);'
            );
            expect(editor.lineTextForBufferRow(9)).toBe('    }');

            const [cursor1, cursor2] = editor.getCursors();
            expect(cursor1.getBufferPosition()).toEqual([4, 0]);
            expect(cursor2.getBufferPosition()).toEqual([8, 0]);
          });
        });
      });
    });

    describe('.insertNewlineBelow()', () => {
      describe('when the operation is undone', () => {
        it('places the cursor back at the previous location', () => {
          editor.setCursorBufferPosition([0, 2]);
          editor.insertNewlineBelow();
          expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
          editor.undo();
          expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
        });
      });

      it("inserts a newline below the cursor's current line, autoindents it, and moves the cursor to the end of the line", () => {
        editor.update({ autoIndent: true });
        editor.insertNewlineBelow();
        expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
        expect(buffer.lineForRow(1)).toBe('  ');
        expect(editor.getCursorBufferPosition()).toEqual([1, 2]);
      });
    });

    describe('.insertNewlineAbove()', () => {
      describe('when the cursor is on first line', () => {
        it('inserts a newline on the first line and moves the cursor to the first line', () => {
          editor.setCursorBufferPosition([0]);
          editor.insertNewlineAbove();
          expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
          expect(editor.lineTextForBufferRow(0)).toBe('');
          expect(editor.lineTextForBufferRow(1)).toBe(
            'var quicksort = function () {'
          );
          expect(editor.buffer.getLineCount()).toBe(14);
        });
      });

      describe('when the cursor is not on the first line', () => {
        it('inserts a newline above the current line and moves the cursor to the inserted line', () => {
          editor.setCursorBufferPosition([3, 4]);
          editor.insertNewlineAbove();
          expect(editor.getCursorBufferPosition()).toEqual([3, 0]);
          expect(editor.lineTextForBufferRow(3)).toBe('');
          expect(editor.lineTextForBufferRow(4)).toBe(
            '    var pivot = items.shift(), current, left = [], right = [];'
          );
          expect(editor.buffer.getLineCount()).toBe(14);

          editor.undo();
          expect(editor.getCursorBufferPosition()).toEqual([3, 4]);
        });
      });

      it('indents the new line to the correct level when editor.autoIndent is true', () => {
        editor.update({ autoIndent: true });

        editor.setText('  var test');
        editor.setCursorBufferPosition([0, 2]);
        editor.insertNewlineAbove();

        expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
        expect(editor.lineTextForBufferRow(0)).toBe('  ');
        expect(editor.lineTextForBufferRow(1)).toBe('  var test');

        editor.setText('\n  var test');
        editor.setCursorBufferPosition([1, 2]);
        editor.insertNewlineAbove();

        expect(editor.getCursorBufferPosition()).toEqual([1, 2]);
        expect(editor.lineTextForBufferRow(0)).toBe('');
        expect(editor.lineTextForBufferRow(1)).toBe('  ');
        expect(editor.lineTextForBufferRow(2)).toBe('  var test');

        editor.setText('function() {\n}');
        editor.setCursorBufferPosition([1, 1]);
        editor.insertNewlineAbove();

        expect(editor.getCursorBufferPosition()).toEqual([1, 2]);
        expect(editor.lineTextForBufferRow(0)).toBe('function() {');
        expect(editor.lineTextForBufferRow(1)).toBe('  ');
        expect(editor.lineTextForBufferRow(2)).toBe('}');
      });
    });

    describe('.insertNewLine()', () => {
      describe('when a new line is appended before a closing tag (e.g. by pressing enter before a selection)', () => {
        it('moves the line down and keeps the indentation level the same when editor.autoIndent is true', () => {
          editor.update({ autoIndent: true });
          editor.setCursorBufferPosition([9, 2]);
          editor.insertNewline();
          expect(editor.lineTextForBufferRow(10)).toBe('  };');
        });
      });

      describe('when a newline is appended with a trailing closing tag behind the cursor (e.g. by pressing enter in the middel of a line)', () => {
        it('indents the new line to the correct level when editor.autoIndent is true and using a curly-bracket language', () => {
          editor.update({ autoIndent: true });
          atom.grammars.assignLanguageMode(editor, 'source.js');
          editor.setText('var test = () => {\n  return true;};');
          editor.setCursorBufferPosition([1, 14]);
          editor.insertNewline();
          expect(editor.indentationForBufferRow(1)).toBe(1);
          expect(editor.indentationForBufferRow(2)).toBe(0);
        });

        it('indents the new line to the current level when editor.autoIndent is true and no increaseIndentPattern is specified', () => {
          atom.grammars.assignLanguageMode(editor, null);
          editor.update({ autoIndent: true });
          editor.setText('  if true');
          editor.setCursorBufferPosition([0, 8]);
          editor.insertNewline();
          expect(editor.getGrammar()).toBe(atom.grammars.nullGrammar);
          expect(editor.indentationForBufferRow(0)).toBe(1);
          expect(editor.indentationForBufferRow(1)).toBe(1);
        });

        it('indents the new line to the correct level when editor.autoIndent is true and using an off-side rule language', async () => {
          await atom.packages.activatePackage('language-coffee-script');
          editor.update({ autoIndent: true });
          atom.grammars.assignLanguageMode(editor, 'source.coffee');
          editor.setText('if true\n  return trueelse\n  return false');
          editor.setCursorBufferPosition([1, 13]);
          editor.insertNewline();
          expect(editor.indentationForBufferRow(1)).toBe(1);
          expect(editor.indentationForBufferRow(2)).toBe(0);
          expect(editor.indentationForBufferRow(3)).toBe(1);
        });
      });

      describe('when a newline is appended on a line that matches the decreaseNextIndentPattern', () => {
        it('indents the new line to the correct level when editor.autoIndent is true', async () => {
          await atom.packages.activatePackage('language-go');
          editor.update({ autoIndent: true });
          atom.grammars.assignLanguageMode(editor, 'source.go');
          editor.setText('fmt.Printf("some%s",\n	"thing")'); // eslint-disable-line no-tabs
          editor.setCursorBufferPosition([1, 10]);
          editor.insertNewline();
          expect(editor.indentationForBufferRow(1)).toBe(1);
          expect(editor.indentationForBufferRow(2)).toBe(0);
        });
      });
    });

    describe('.backspace()', () => {
      describe('when there is a single cursor', () => {
        let changeScreenRangeHandler = null;

        beforeEach(() => {
          const selection = editor.getLastSelection();
          changeScreenRangeHandler = jasmine.createSpy(
            'changeScreenRangeHandler'
          );
          selection.onDidChangeRange(changeScreenRangeHandler);
        });

        describe('when the cursor is on the middle of the line', () => {
          it('removes the character before the cursor', () => {
            editor.setCursorScreenPosition({ row: 1, column: 7 });
            expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');

            editor.backspace();

            const line = buffer.lineForRow(1);
            expect(line).toBe('  var ort = function(items) {');
            expect(editor.getCursorScreenPosition()).toEqual({
              row: 1,
              column: 6
            });
            expect(changeScreenRangeHandler).toHaveBeenCalled();
          });
        });

        describe('when the cursor is at the beginning of a line', () => {
          it('joins it with the line above', () => {
            const originalLine0 = buffer.lineForRow(0);
            expect(originalLine0).toBe('var quicksort = function () {');
            expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');

            editor.setCursorScreenPosition({ row: 1, column: 0 });
            editor.backspace();

            const line0 = buffer.lineForRow(0);
            const line1 = buffer.lineForRow(1);
            expect(line0).toBe(
              'var quicksort = function () {  var sort = function(items) {'
            );
            expect(line1).toBe('    if (items.length <= 1) return items;');
            expect(editor.getCursorScreenPosition()).toEqual([
              0,
              originalLine0.length
            ]);

            expect(changeScreenRangeHandler).toHaveBeenCalled();
          });
        });

        describe('when the cursor is at the first column of the first line', () => {
          it("does nothing, but doesn't raise an error", () => {
            editor.setCursorScreenPosition({ row: 0, column: 0 });
            editor.backspace();
          });
        });

        describe('when the cursor is after a fold', () => {
          it('deletes the folded range', () => {
            editor.foldBufferRange([[4, 7], [5, 8]]);
            editor.setCursorBufferPosition([5, 8]);
            editor.backspace();

            expect(buffer.lineForRow(4)).toBe('    whirrent = items.shift();');
            expect(editor.isFoldedAtBufferRow(4)).toBe(false);
          });
        });

        describe('when the cursor is in the middle of a line below a fold', () => {
          it('backspaces as normal', () => {
            editor.setCursorScreenPosition([4, 0]);
            editor.foldCurrentRow();
            editor.setCursorScreenPosition([5, 5]);
            editor.backspace();

            expect(buffer.lineForRow(7)).toBe('    }');
            expect(buffer.lineForRow(8)).toBe(
              '    eturn sort(left).concat(pivot).concat(sort(right));'
            );
          });
        });

        describe('when the cursor is on a folded screen line', () => {
          it('deletes the contents of the fold before the cursor', () => {
            editor.setCursorBufferPosition([3, 0]);
            editor.foldCurrentRow();
            editor.backspace();

            expect(buffer.lineForRow(1)).toBe(
              '  var sort = function(items)     var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.getCursorScreenPosition()).toEqual([1, 29]);
          });
        });
      });

      describe('when there are multiple cursors', () => {
        describe('when cursors are on the same line', () => {
          it('removes the characters preceding each cursor', () => {
            editor.setCursorScreenPosition([3, 13]);
            editor.addCursorAtScreenPosition([3, 38]);

            editor.backspace();

            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivo = items.shift(), curren, left = [], right = [];'
            );

            const [cursor1, cursor2] = editor.getCursors();
            expect(cursor1.getBufferPosition()).toEqual([3, 12]);
            expect(cursor2.getBufferPosition()).toEqual([3, 36]);

            const [selection1, selection2] = editor.getSelections();
            expect(selection1.isEmpty()).toBeTruthy();
            expect(selection2.isEmpty()).toBeTruthy();
          });
        });

        describe('when cursors are on different lines', () => {
          describe('when the cursors are in the middle of their lines', () =>
            it('removes the characters preceding each cursor', () => {
              editor.setCursorScreenPosition([3, 13]);
              editor.addCursorAtScreenPosition([4, 10]);

              editor.backspace();

              expect(editor.lineTextForBufferRow(3)).toBe(
                '    var pivo = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    whileitems.length > 0) {'
              );

              const [cursor1, cursor2] = editor.getCursors();
              expect(cursor1.getBufferPosition()).toEqual([3, 12]);
              expect(cursor2.getBufferPosition()).toEqual([4, 9]);

              const [selection1, selection2] = editor.getSelections();
              expect(selection1.isEmpty()).toBeTruthy();
              expect(selection2.isEmpty()).toBeTruthy();
            }));

          describe('when the cursors are on the first column of their lines', () =>
            it('removes the newlines preceding each cursor', () => {
              editor.setCursorScreenPosition([3, 0]);
              editor.addCursorAtScreenPosition([6, 0]);

              editor.backspace();
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    if (items.length <= 1) return items;    var pivot = items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '      current = items.shift();      current < pivot ? left.push(current) : right.push(current);'
              );
              expect(editor.lineTextForBufferRow(5)).toBe('    }');

              const [cursor1, cursor2] = editor.getCursors();
              expect(cursor1.getBufferPosition()).toEqual([2, 40]);
              expect(cursor2.getBufferPosition()).toEqual([4, 30]);
            }));
        });
      });

      describe('when there is a single selection', () => {
        it('deletes the selection, but not the character before it', () => {
          editor.setSelectedBufferRange([[0, 5], [0, 9]]);
          editor.backspace();
          expect(editor.buffer.lineForRow(0)).toBe('var qsort = function () {');
        });

        describe('when the selection ends on a folded line', () => {
          it('preserves the fold', () => {
            editor.setSelectedBufferRange([[3, 0], [4, 0]]);
            editor.foldBufferRow(4);
            editor.backspace();

            expect(buffer.lineForRow(3)).toBe('    while(items.length > 0) {');
            expect(editor.isFoldedAtScreenRow(3)).toBe(true);
          });
        });
      });

      describe('when there are multiple selections', () => {
        it('removes all selected text', () => {
          editor.setSelectedBufferRanges([
            [[0, 4], [0, 13]],
            [[0, 16], [0, 24]]
          ]);
          editor.backspace();
          expect(editor.lineTextForBufferRow(0)).toBe('var  =  () {');
        });
      });
    });

    describe('.deleteToPreviousWordBoundary()', () => {
      describe('when no text is selected', () => {
        it('deletes to the previous word boundary', () => {
          editor.setCursorBufferPosition([0, 16]);
          editor.addCursorAtBufferPosition([1, 21]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToPreviousWordBoundary();
          expect(buffer.lineForRow(0)).toBe('var quicksort =function () {');
          expect(buffer.lineForRow(1)).toBe('  var sort = (items) {');
          expect(cursor1.getBufferPosition()).toEqual([0, 15]);
          expect(cursor2.getBufferPosition()).toEqual([1, 13]);

          editor.deleteToPreviousWordBoundary();
          expect(buffer.lineForRow(0)).toBe('var quicksort function () {');
          expect(buffer.lineForRow(1)).toBe('  var sort =(items) {');
          expect(cursor1.getBufferPosition()).toEqual([0, 14]);
          expect(cursor2.getBufferPosition()).toEqual([1, 12]);
        });
      });

      describe('when text is selected', () => {
        it('deletes only selected text', () => {
          editor.setSelectedBufferRange([[1, 24], [1, 27]]);
          editor.deleteToPreviousWordBoundary();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
        });
      });
    });

    describe('.deleteToNextWordBoundary()', () => {
      describe('when no text is selected', () => {
        it('deletes to the next word boundary', () => {
          editor.setCursorBufferPosition([0, 15]);
          editor.addCursorAtBufferPosition([1, 24]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToNextWordBoundary();
          expect(buffer.lineForRow(0)).toBe('var quicksort =function () {');
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
          expect(cursor1.getBufferPosition()).toEqual([0, 15]);
          expect(cursor2.getBufferPosition()).toEqual([1, 24]);

          editor.deleteToNextWordBoundary();
          expect(buffer.lineForRow(0)).toBe('var quicksort = () {');
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it {');
          expect(cursor1.getBufferPosition()).toEqual([0, 15]);
          expect(cursor2.getBufferPosition()).toEqual([1, 24]);

          editor.deleteToNextWordBoundary();
          expect(buffer.lineForRow(0)).toBe('var quicksort =() {');
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it{');
          expect(cursor1.getBufferPosition()).toEqual([0, 15]);
          expect(cursor2.getBufferPosition()).toEqual([1, 24]);
        });
      });

      describe('when text is selected', () => {
        it('deletes only selected text', () => {
          editor.setSelectedBufferRange([[1, 24], [1, 27]]);
          editor.deleteToNextWordBoundary();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
        });
      });
    });

    describe('.deleteToBeginningOfWord()', () => {
      describe('when no text is selected', () => {
        it('deletes all text between the cursor and the beginning of the word', () => {
          editor.setCursorBufferPosition([1, 24]);
          editor.addCursorAtBufferPosition([3, 5]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToBeginningOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(ems) {');
          expect(buffer.lineForRow(3)).toBe(
            '    ar pivot = items.shift(), current, left = [], right = [];'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 22]);
          expect(cursor2.getBufferPosition()).toEqual([3, 4]);

          editor.deleteToBeginningOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = functionems) {');
          expect(buffer.lineForRow(2)).toBe(
            '    if (items.length <= 1) return itemsar pivot = items.shift(), current, left = [], right = [];'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 21]);
          expect(cursor2.getBufferPosition()).toEqual([2, 39]);

          editor.deleteToBeginningOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = ems) {');
          expect(buffer.lineForRow(2)).toBe(
            '    if (items.length <= 1) return ar pivot = items.shift(), current, left = [], right = [];'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 13]);
          expect(cursor2.getBufferPosition()).toEqual([2, 34]);

          editor.setText('  var sort');
          editor.setCursorBufferPosition([0, 2]);
          editor.deleteToBeginningOfWord();
          expect(buffer.lineForRow(0)).toBe('var sort');
        });
      });

      describe('when text is selected', () => {
        it('deletes only selected text', () => {
          editor.setSelectedBufferRanges([
            [[1, 24], [1, 27]],
            [[2, 0], [2, 4]]
          ]);
          editor.deleteToBeginningOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
          expect(buffer.lineForRow(2)).toBe(
            'if (items.length <= 1) return items;'
          );
        });
      });
    });

    describe('.deleteToEndOfLine()', () => {
      describe('when no text is selected', () => {
        it('deletes all text between the cursor and the end of the line', () => {
          editor.setCursorBufferPosition([1, 24]);
          editor.addCursorAtBufferPosition([2, 5]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToEndOfLine();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it');
          expect(buffer.lineForRow(2)).toBe('    i');
          expect(cursor1.getBufferPosition()).toEqual([1, 24]);
          expect(cursor2.getBufferPosition()).toEqual([2, 5]);
        });

        describe('when at the end of the line', () => {
          it('deletes the next newline', () => {
            editor.setCursorBufferPosition([1, 30]);
            editor.deleteToEndOfLine();
            expect(buffer.lineForRow(1)).toBe(
              '  var sort = function(items) {    if (items.length <= 1) return items;'
            );
          });
        });
      });

      describe('when text is selected', () => {
        it('deletes only the text in the selection', () => {
          editor.setSelectedBufferRanges([
            [[1, 24], [1, 27]],
            [[2, 0], [2, 4]]
          ]);
          editor.deleteToEndOfLine();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
          expect(buffer.lineForRow(2)).toBe(
            'if (items.length <= 1) return items;'
          );
        });
      });
    });

    describe('.deleteToBeginningOfLine()', () => {
      describe('when no text is selected', () => {
        it('deletes all text between the cursor and the beginning of the line', () => {
          editor.setCursorBufferPosition([1, 24]);
          editor.addCursorAtBufferPosition([2, 5]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToBeginningOfLine();
          expect(buffer.lineForRow(1)).toBe('ems) {');
          expect(buffer.lineForRow(2)).toBe(
            'f (items.length <= 1) return items;'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 0]);
          expect(cursor2.getBufferPosition()).toEqual([2, 0]);
        });

        describe('when at the beginning of the line', () => {
          it('deletes the newline', () => {
            editor.setCursorBufferPosition([2]);
            editor.deleteToBeginningOfLine();
            expect(buffer.lineForRow(1)).toBe(
              '  var sort = function(items) {    if (items.length <= 1) return items;'
            );
          });
        });
      });

      describe('when text is selected', () => {
        it('still deletes all text to beginning of the line', () => {
          editor.setSelectedBufferRanges([
            [[1, 24], [1, 27]],
            [[2, 0], [2, 4]]
          ]);
          editor.deleteToBeginningOfLine();
          expect(buffer.lineForRow(1)).toBe('ems) {');
          expect(buffer.lineForRow(2)).toBe(
            '    if (items.length <= 1) return items;'
          );
        });
      });
    });

    describe('.delete()', () => {
      describe('when there is a single cursor', () => {
        describe('when the cursor is on the middle of a line', () => {
          it('deletes the character following the cursor', () => {
            editor.setCursorScreenPosition([1, 6]);
            editor.delete();
            expect(buffer.lineForRow(1)).toBe('  var ort = function(items) {');
          });
        });

        describe('when the cursor is on the end of a line', () => {
          it('joins the line with the following line', () => {
            editor.setCursorScreenPosition([1, buffer.lineForRow(1).length]);
            editor.delete();
            expect(buffer.lineForRow(1)).toBe(
              '  var sort = function(items) {    if (items.length <= 1) return items;'
            );
          });
        });

        describe('when the cursor is on the last column of the last line', () => {
          it("does nothing, but doesn't raise an error", () => {
            editor.setCursorScreenPosition([12, buffer.lineForRow(12).length]);
            editor.delete();
            expect(buffer.lineForRow(12)).toBe('};');
          });
        });

        describe('when the cursor is before a fold', () => {
          it('only deletes the lines inside the fold', () => {
            editor.foldBufferRange([[3, 6], [4, 8]]);
            editor.setCursorScreenPosition([3, 6]);
            const cursorPositionBefore = editor.getCursorScreenPosition();

            editor.delete();

            expect(buffer.lineForRow(3)).toBe('    vae(items.length > 0) {');
            expect(buffer.lineForRow(4)).toBe('      current = items.shift();');
            expect(editor.getCursorScreenPosition()).toEqual(
              cursorPositionBefore
            );
          });
        });

        describe('when the cursor is in the middle a line above a fold', () => {
          it('deletes as normal', () => {
            editor.foldBufferRow(4);
            editor.setCursorScreenPosition([3, 4]);
            editor.delete();

            expect(buffer.lineForRow(3)).toBe(
              '    ar pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.isFoldedAtScreenRow(4)).toBe(true);
            expect(editor.getCursorScreenPosition()).toEqual([3, 4]);
          });
        });

        describe('when the cursor is inside a fold', () => {
          it('removes the folded content after the cursor', () => {
            editor.foldBufferRange([[2, 6], [6, 21]]);
            editor.setCursorBufferPosition([4, 9]);

            editor.delete();

            expect(buffer.lineForRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(buffer.lineForRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(buffer.lineForRow(4)).toBe(
              '    while ? left.push(current) : right.push(current);'
            );
            expect(buffer.lineForRow(5)).toBe('    }');
            expect(editor.getCursorBufferPosition()).toEqual([4, 9]);
          });
        });
      });

      describe('when there are multiple cursors', () => {
        describe('when cursors are on the same line', () => {
          it('removes the characters following each cursor', () => {
            editor.setCursorScreenPosition([3, 13]);
            editor.addCursorAtScreenPosition([3, 38]);

            editor.delete();

            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot= items.shift(), current left = [], right = [];'
            );

            const [cursor1, cursor2] = editor.getCursors();
            expect(cursor1.getBufferPosition()).toEqual([3, 13]);
            expect(cursor2.getBufferPosition()).toEqual([3, 37]);

            const [selection1, selection2] = editor.getSelections();
            expect(selection1.isEmpty()).toBeTruthy();
            expect(selection2.isEmpty()).toBeTruthy();
          });
        });

        describe('when cursors are on different lines', () => {
          describe('when the cursors are in the middle of the lines', () =>
            it('removes the characters following each cursor', () => {
              editor.setCursorScreenPosition([3, 13]);
              editor.addCursorAtScreenPosition([4, 10]);

              editor.delete();

              expect(editor.lineTextForBufferRow(3)).toBe(
                '    var pivot= items.shift(), current, left = [], right = [];'
              );
              expect(editor.lineTextForBufferRow(4)).toBe(
                '    while(tems.length > 0) {'
              );

              const [cursor1, cursor2] = editor.getCursors();
              expect(cursor1.getBufferPosition()).toEqual([3, 13]);
              expect(cursor2.getBufferPosition()).toEqual([4, 10]);

              const [selection1, selection2] = editor.getSelections();
              expect(selection1.isEmpty()).toBeTruthy();
              expect(selection2.isEmpty()).toBeTruthy();
            }));

          describe('when the cursors are at the end of their lines', () =>
            it('removes the newlines following each cursor', () => {
              editor.setCursorScreenPosition([0, 29]);
              editor.addCursorAtScreenPosition([1, 30]);

              editor.delete();

              expect(editor.lineTextForBufferRow(0)).toBe(
                'var quicksort = function () {  var sort = function(items) {    if (items.length <= 1) return items;'
              );

              const [cursor1, cursor2] = editor.getCursors();
              expect(cursor1.getBufferPosition()).toEqual([0, 29]);
              expect(cursor2.getBufferPosition()).toEqual([0, 59]);
            }));
        });
      });

      describe('when there is a single selection', () => {
        it('deletes the selection, but not the character following it', () => {
          editor.setSelectedBufferRanges([
            [[1, 24], [1, 27]],
            [[2, 0], [2, 4]]
          ]);
          editor.delete();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
          expect(buffer.lineForRow(2)).toBe(
            'if (items.length <= 1) return items;'
          );
          expect(editor.getLastSelection().isEmpty()).toBeTruthy();
        });
      });

      describe('when there are multiple selections', () =>
        describe('when selections are on the same line', () => {
          it('removes all selected text', () => {
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[0, 16], [0, 24]]
            ]);
            editor.delete();
            expect(editor.lineTextForBufferRow(0)).toBe('var  =  () {');
          });
        }));
    });

    describe('.deleteToEndOfWord()', () => {
      describe('when no text is selected', () => {
        it('deletes to the end of the word', () => {
          editor.setCursorBufferPosition([1, 24]);
          editor.addCursorAtBufferPosition([2, 5]);
          const [cursor1, cursor2] = editor.getCursors();

          editor.deleteToEndOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
          expect(buffer.lineForRow(2)).toBe(
            '    i (items.length <= 1) return items;'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 24]);
          expect(cursor2.getBufferPosition()).toEqual([2, 5]);

          editor.deleteToEndOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it {');
          expect(buffer.lineForRow(2)).toBe(
            '    iitems.length <= 1) return items;'
          );
          expect(cursor1.getBufferPosition()).toEqual([1, 24]);
          expect(cursor2.getBufferPosition()).toEqual([2, 5]);
        });
      });

      describe('when text is selected', () => {
        it('deletes only selected text', () => {
          editor.setSelectedBufferRange([[1, 24], [1, 27]]);
          editor.deleteToEndOfWord();
          expect(buffer.lineForRow(1)).toBe('  var sort = function(it) {');
        });
      });
    });

    describe('.indent()', () => {
      describe('when the selection is empty', () => {
        describe('when autoIndent is disabled', () => {
          describe("if 'softTabs' is true (the default)", () => {
            it("inserts 'tabLength' spaces into the buffer", () => {
              const tabRegex = new RegExp(`^[ ]{${editor.getTabLength()}}`);
              expect(buffer.lineForRow(0)).not.toMatch(tabRegex);
              editor.indent();
              expect(buffer.lineForRow(0)).toMatch(tabRegex);
            });

            it('respects the tab stops when cursor is in the middle of a tab', () => {
              editor.setTabLength(4);
              buffer.insert([12, 2], '\n ');
              editor.setCursorBufferPosition([13, 1]);
              editor.indent();
              expect(buffer.lineForRow(13)).toMatch(/^\s+$/);
              expect(buffer.lineForRow(13).length).toBe(4);
              expect(editor.getCursorBufferPosition()).toEqual([13, 4]);

              buffer.insert([13, 0], '  ');
              editor.setCursorBufferPosition([13, 6]);
              editor.indent();
              expect(buffer.lineForRow(13).length).toBe(8);
            });
          });

          describe("if 'softTabs' is false", () =>
            it('insert a \t into the buffer', () => {
              editor.setSoftTabs(false);
              expect(buffer.lineForRow(0)).not.toMatch(/^\t/);
              editor.indent();
              expect(buffer.lineForRow(0)).toMatch(/^\t/);
            }));
        });

        describe('when autoIndent is enabled', () => {
          describe("when the cursor's column is less than the suggested level of indentation", () => {
            describe("when 'softTabs' is true (the default)", () => {
              it('moves the cursor to the end of the leading whitespace and inserts enough whitespace to bring the line to the suggested level of indentation', () => {
                buffer.insert([5, 0], '  \n');
                editor.setCursorBufferPosition([5, 0]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(5)).toMatch(/^\s+$/);
                expect(buffer.lineForRow(5).length).toBe(6);
                expect(editor.getCursorBufferPosition()).toEqual([5, 6]);
              });

              it('respects the tab stops when cursor is in the middle of a tab', () => {
                editor.setTabLength(4);
                buffer.insert([12, 2], '\n ');
                editor.setCursorBufferPosition([13, 1]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(13)).toMatch(/^\s+$/);
                expect(buffer.lineForRow(13).length).toBe(4);
                expect(editor.getCursorBufferPosition()).toEqual([13, 4]);

                buffer.insert([13, 0], '  ');
                editor.setCursorBufferPosition([13, 6]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(13).length).toBe(8);
              });
            });

            describe("when 'softTabs' is false", () => {
              it('moves the cursor to the end of the leading whitespace and inserts enough tabs to bring the line to the suggested level of indentation', () => {
                convertToHardTabs(buffer);
                editor.setSoftTabs(false);
                buffer.insert([5, 0], '\t\n');
                editor.setCursorBufferPosition([5, 0]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(5)).toMatch(/^\t\t\t$/);
                expect(editor.getCursorBufferPosition()).toEqual([5, 3]);
              });

              describe('when the difference between the suggested level of indentation and the current level of indentation is greater than 0 but less than 1', () =>
                it('inserts one tab', () => {
                  editor.setSoftTabs(false);
                  buffer.setText(' \ntest');
                  editor.setCursorBufferPosition([1, 0]);

                  editor.indent({ autoIndent: true });
                  expect(buffer.lineForRow(1)).toBe('\ttest');
                  expect(editor.getCursorBufferPosition()).toEqual([1, 1]);
                }));
            });
          });

          describe("when the line's indent level is greater than the suggested level of indentation", () => {
            describe("when 'softTabs' is true (the default)", () =>
              it("moves the cursor to the end of the leading whitespace and inserts 'tabLength' spaces into the buffer", () => {
                buffer.insert([7, 0], '      \n');
                editor.setCursorBufferPosition([7, 2]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(7)).toMatch(/^\s+$/);
                expect(buffer.lineForRow(7).length).toBe(8);
                expect(editor.getCursorBufferPosition()).toEqual([7, 8]);
              }));

            describe("when 'softTabs' is false", () =>
              it('moves the cursor to the end of the leading whitespace and inserts \t into the buffer', () => {
                convertToHardTabs(buffer);
                editor.setSoftTabs(false);
                buffer.insert([7, 0], '\t\t\t\n');
                editor.setCursorBufferPosition([7, 1]);
                editor.indent({ autoIndent: true });
                expect(buffer.lineForRow(7)).toMatch(/^\t\t\t\t$/);
                expect(editor.getCursorBufferPosition()).toEqual([7, 4]);
              }));
          });
        });
      });

      describe('when the selection is not empty', () => {
        it('indents the selected lines', () => {
          editor.setSelectedBufferRange([[0, 0], [10, 0]]);
          const selection = editor.getLastSelection();
          spyOn(selection, 'indentSelectedRows');
          editor.indent();
          expect(selection.indentSelectedRows).toHaveBeenCalled();
        });
      });

      describe('if editor.softTabs is false', () => {
        it('inserts a tab character into the buffer', () => {
          editor.setSoftTabs(false);
          expect(buffer.lineForRow(0)).not.toMatch(/^\t/);
          editor.indent();
          expect(buffer.lineForRow(0)).toMatch(/^\t/);
          expect(editor.getCursorBufferPosition()).toEqual([0, 1]);
          expect(editor.getCursorScreenPosition()).toEqual([
            0,
            editor.getTabLength()
          ]);

          editor.indent();
          expect(buffer.lineForRow(0)).toMatch(/^\t\t/);
          expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
          expect(editor.getCursorScreenPosition()).toEqual([
            0,
            editor.getTabLength() * 2
          ]);
        });
      });
    });

    describe('clipboard operations', () => {
      describe('.cutSelectedText()', () => {
        it('removes the selected text from the buffer and places it on the clipboard', () => {
          editor.setSelectedBufferRanges([
            [[0, 4], [0, 13]],
            [[1, 6], [1, 10]]
          ]);
          editor.cutSelectedText();
          expect(buffer.lineForRow(0)).toBe('var  = function () {');
          expect(buffer.lineForRow(1)).toBe('  var  = function(items) {');
          expect(clipboard.readText()).toBe('quicksort\nsort');
        });

        describe('when no text is selected', () => {
          beforeEach(() =>
            editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[5, 0], [5, 0]]])
          );

          it('cuts the lines on which there are cursors', () => {
            editor.cutSelectedText();
            expect(buffer.getLineCount()).toBe(11);
            expect(buffer.lineForRow(1)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(buffer.lineForRow(4)).toBe(
              '      current < pivot ? left.push(current) : right.push(current);'
            );
            expect(atom.clipboard.read()).toEqual(
              [
                'var quicksort = function () {',
                '',
                '      current = items.shift();',
                ''
              ].join('\n')
            );
          });
        });

        describe('when many selections get added in shuffle order', () => {
          it('cuts them in order', () => {
            editor.setSelectedBufferRanges([
              [[2, 8], [2, 13]],
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]]
            ]);
            editor.cutSelectedText();
            expect(atom.clipboard.read()).toEqual(`quicksort\nsort\nitems`);
          });
        });
      });

      describe('.cutToEndOfLine()', () => {
        describe('when soft wrap is on', () => {
          it('cuts up to the end of the line', () => {
            editor.setSoftWrapped(true);
            editor.setDefaultCharWidth(1);
            editor.setEditorWidthInChars(25);
            editor.setCursorScreenPosition([2, 6]);
            editor.cutToEndOfLine();
            expect(editor.lineTextForScreenRow(2)).toBe(
              '  var  function(items) {'
            );
          });
        });

        describe('when soft wrap is off', () => {
          describe('when nothing is selected', () =>
            it('cuts up to the end of the line', () => {
              editor.setCursorBufferPosition([2, 20]);
              editor.addCursorAtBufferPosition([3, 20]);
              editor.cutToEndOfLine();
              expect(buffer.lineForRow(2)).toBe('    if (items.length');
              expect(buffer.lineForRow(3)).toBe('    var pivot = item');
              expect(atom.clipboard.read()).toBe(
                ' <= 1) return items;\ns.shift(), current, left = [], right = [];'
              );
            }));

          describe('when text is selected', () =>
            it('only cuts the selected text, not to the end of the line', () => {
              editor.setSelectedBufferRanges([
                [[2, 20], [2, 30]],
                [[3, 20], [3, 20]]
              ]);
              editor.cutToEndOfLine();
              expect(buffer.lineForRow(2)).toBe(
                '    if (items.lengthurn items;'
              );
              expect(buffer.lineForRow(3)).toBe('    var pivot = item');
              expect(atom.clipboard.read()).toBe(
                ' <= 1) ret\ns.shift(), current, left = [], right = [];'
              );
            }));
        });
      });

      describe('.cutToEndOfBufferLine()', () => {
        beforeEach(() => {
          editor.setSoftWrapped(true);
          editor.setEditorWidthInChars(10);
        });

        describe('when nothing is selected', () => {
          it('cuts up to the end of the buffer line', () => {
            editor.setCursorBufferPosition([2, 20]);
            editor.addCursorAtBufferPosition([3, 20]);
            editor.cutToEndOfBufferLine();
            expect(buffer.lineForRow(2)).toBe('    if (items.length');
            expect(buffer.lineForRow(3)).toBe('    var pivot = item');
            expect(atom.clipboard.read()).toBe(
              ' <= 1) return items;\ns.shift(), current, left = [], right = [];'
            );
          });
        });

        describe('when text is selected', () => {
          it('only cuts the selected text, not to the end of the buffer line', () => {
            editor.setSelectedBufferRanges([
              [[2, 20], [2, 30]],
              [[3, 20], [3, 20]]
            ]);
            editor.cutToEndOfBufferLine();
            expect(buffer.lineForRow(2)).toBe('    if (items.lengthurn items;');
            expect(buffer.lineForRow(3)).toBe('    var pivot = item');
            expect(atom.clipboard.read()).toBe(
              ' <= 1) ret\ns.shift(), current, left = [], right = [];'
            );
          });
        });
      });

      describe('.copySelectedText()', () => {
        it('copies selected text onto the clipboard', () => {
          editor.setSelectedBufferRanges([
            [[0, 4], [0, 13]],
            [[1, 6], [1, 10]],
            [[2, 8], [2, 13]]
          ]);
          editor.copySelectedText();

          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
          expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');
          expect(buffer.lineForRow(2)).toBe(
            '    if (items.length <= 1) return items;'
          );
          expect(clipboard.readText()).toBe('quicksort\nsort\nitems');
          expect(atom.clipboard.read()).toEqual('quicksort\nsort\nitems');
        });

        describe('when no text is selected', () => {
          beforeEach(() => {
            editor.setSelectedBufferRanges([
              [[1, 5], [1, 5]],
              [[5, 8], [5, 8]]
            ]);
          });

          it('copies the lines on which there are cursors', () => {
            editor.copySelectedText();
            expect(atom.clipboard.read()).toEqual(
              [
                '  var sort = function(items) {\n',
                '      current = items.shift();\n'
              ].join('\n')
            );
            expect(editor.getSelectedBufferRanges()).toEqual([
              [[1, 5], [1, 5]],
              [[5, 8], [5, 8]]
            ]);
          });
        });

        describe('when many selections get added in shuffle order', () => {
          it('copies them in order', () => {
            editor.setSelectedBufferRanges([
              [[2, 8], [2, 13]],
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]]
            ]);
            editor.copySelectedText();
            expect(atom.clipboard.read()).toEqual(`quicksort\nsort\nitems`);
          });
        });
      });

      describe('.copyOnlySelectedText()', () => {
        describe('when thee are multiple selections', () => {
          it('copies selected text onto the clipboard', () => {
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]],
              [[2, 8], [2, 13]]
            ]);

            editor.copyOnlySelectedText();
            expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
            expect(buffer.lineForRow(1)).toBe('  var sort = function(items) {');
            expect(buffer.lineForRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(clipboard.readText()).toBe('quicksort\nsort\nitems');
            expect(atom.clipboard.read()).toEqual(`quicksort\nsort\nitems`);
          });
        });

        describe('when no text is selected', () => {
          it('does not copy anything', () => {
            editor.setCursorBufferPosition([1, 5]);
            editor.copyOnlySelectedText();
            expect(atom.clipboard.read()).toEqual('initial clipboard content');
          });
        });
      });

      describe('.pasteText()', () => {
        it('pastes text into the buffer', () => {
          editor.setSelectedBufferRanges([
            [[0, 4], [0, 13]],
            [[1, 6], [1, 10]]
          ]);
          atom.clipboard.write('first');
          editor.pasteText();
          expect(editor.lineTextForBufferRow(0)).toBe(
            'var first = function () {'
          );
          expect(editor.lineTextForBufferRow(1)).toBe(
            '  var first = function(items) {'
          );
        });

        it('notifies ::onWillInsertText observers', () => {
          const insertedStrings = [];
          editor.onWillInsertText(function({ text, cancel }) {
            insertedStrings.push(text);
            cancel();
          });

          atom.clipboard.write('hello');
          editor.pasteText();

          expect(insertedStrings).toEqual(['hello']);
        });

        it('notifies ::onDidInsertText observers', () => {
          const insertedStrings = [];
          editor.onDidInsertText(({ text, range }) =>
            insertedStrings.push(text)
          );

          atom.clipboard.write('hello');
          editor.pasteText();

          expect(insertedStrings).toEqual(['hello']);
        });

        describe('when `autoIndentOnPaste` is true', () => {
          beforeEach(() => editor.update({ autoIndentOnPaste: true }));

          describe('when pasting multiple lines before any non-whitespace characters', () => {
            it('auto-indents the lines spanned by the pasted text, based on the first pasted line', () => {
              atom.clipboard.write('a(x);\n  b(x);\n    c(x);\n', {
                indentBasis: 0
              });
              editor.setCursorBufferPosition([5, 0]);
              editor.pasteText();

              // Adjust the indentation of the pasted lines while preserving
              // their indentation relative to each other. Also preserve the
              // indentation of the following line.
              expect(editor.lineTextForBufferRow(5)).toBe('      a(x);');
              expect(editor.lineTextForBufferRow(6)).toBe('        b(x);');
              expect(editor.lineTextForBufferRow(7)).toBe('          c(x);');
              expect(editor.lineTextForBufferRow(8)).toBe(
                '      current = items.shift();'
              );
            });

            it('auto-indents lines with a mix of hard tabs and spaces without removing spaces', () => {
              editor.setSoftTabs(false);
              expect(editor.indentationForBufferRow(5)).toBe(3);

              atom.clipboard.write('/**\n\t * testing\n\t * indent\n\t **/\n', {
                indentBasis: 1
              });
              editor.setCursorBufferPosition([5, 0]);
              editor.pasteText();

              // Do not lose the alignment spaces
              expect(editor.lineTextForBufferRow(5)).toBe('\t\t\t/**');
              expect(editor.lineTextForBufferRow(6)).toBe('\t\t\t * testing');
              expect(editor.lineTextForBufferRow(7)).toBe('\t\t\t * indent');
              expect(editor.lineTextForBufferRow(8)).toBe('\t\t\t **/');
            });
          });

          describe('when pasting line(s) above a line that matches the decreaseIndentPattern', () =>
            it('auto-indents based on the pasted line(s) only', () => {
              atom.clipboard.write('a(x);\n  b(x);\n    c(x);\n', {
                indentBasis: 0
              });
              editor.setCursorBufferPosition([7, 0]);
              editor.pasteText();

              expect(editor.lineTextForBufferRow(7)).toBe('      a(x);');
              expect(editor.lineTextForBufferRow(8)).toBe('        b(x);');
              expect(editor.lineTextForBufferRow(9)).toBe('          c(x);');
              expect(editor.lineTextForBufferRow(10)).toBe('    }');
            }));

          describe('when pasting a line of text without line ending', () =>
            it('does not auto-indent the text', () => {
              atom.clipboard.write('a(x);', { indentBasis: 0 });
              editor.setCursorBufferPosition([5, 0]);
              editor.pasteText();

              expect(editor.lineTextForBufferRow(5)).toBe(
                'a(x);      current = items.shift();'
              );
              expect(editor.lineTextForBufferRow(6)).toBe(
                '      current < pivot ? left.push(current) : right.push(current);'
              );
            }));

          describe('when pasting on a line after non-whitespace characters', () =>
            it('does not auto-indent the affected line', () => {
              // Before the paste, the indentation is non-standard.
              editor.setText(dedent`\
                if (x) {
                    y();
                }\
              `);

              atom.clipboard.write(' z();\n h();');
              editor.setCursorBufferPosition([1, Infinity]);

              // The indentation of the non-standard line is unchanged.
              editor.pasteText();
              expect(editor.lineTextForBufferRow(1)).toBe('    y(); z();');
              expect(editor.lineTextForBufferRow(2)).toBe(' h();');
            }));
        });

        describe('when `autoIndentOnPaste` is false', () => {
          beforeEach(() => editor.update({ autoIndentOnPaste: false }));

          describe('when the cursor is indented further than the original copied text', () =>
            it('increases the indentation of the copied lines to match', () => {
              editor.setSelectedBufferRange([[1, 2], [3, 0]]);
              editor.copySelectedText();

              editor.setCursorBufferPosition([5, 6]);
              editor.pasteText();

              expect(editor.lineTextForBufferRow(5)).toBe(
                '      var sort = function(items) {'
              );
              expect(editor.lineTextForBufferRow(6)).toBe(
                '        if (items.length <= 1) return items;'
              );
            }));

          describe('when the cursor is indented less far than the original copied text', () =>
            it('decreases the indentation of the copied lines to match', () => {
              editor.setSelectedBufferRange([[6, 6], [8, 0]]);
              editor.copySelectedText();

              editor.setCursorBufferPosition([1, 2]);
              editor.pasteText();

              expect(editor.lineTextForBufferRow(1)).toBe(
                '  current < pivot ? left.push(current) : right.push(current);'
              );
              expect(editor.lineTextForBufferRow(2)).toBe('}');
            }));

          describe('when the first copied line has leading whitespace', () =>
            it("preserves the line's leading whitespace", () => {
              editor.setSelectedBufferRange([[4, 0], [6, 0]]);
              editor.copySelectedText();

              editor.setCursorBufferPosition([0, 0]);
              editor.pasteText();

              expect(editor.lineTextForBufferRow(0)).toBe(
                '    while(items.length > 0) {'
              );
              expect(editor.lineTextForBufferRow(1)).toBe(
                '      current = items.shift();'
              );
            }));
        });

        describe('when the clipboard has many selections', () => {
          beforeEach(() => {
            editor.update({ autoIndentOnPaste: false });
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]]
            ]);
            editor.copySelectedText();
          });

          it('pastes each selection in order separately into the buffer', () => {
            editor.setSelectedBufferRanges([
              [[1, 6], [1, 10]],
              [[0, 4], [0, 13]]
            ]);

            editor.moveRight();
            editor.insertText('_');
            editor.pasteText();
            expect(editor.lineTextForBufferRow(0)).toBe(
              'var quicksort_quicksort = function () {'
            );
            expect(editor.lineTextForBufferRow(1)).toBe(
              '  var sort_sort = function(items) {'
            );
          });

          describe('and the selections count does not match', () => {
            beforeEach(() =>
              editor.setSelectedBufferRanges([[[0, 4], [0, 13]]])
            );

            it('pastes the whole text into the buffer', () => {
              editor.pasteText();
              expect(editor.lineTextForBufferRow(0)).toBe('var quicksort');
              expect(editor.lineTextForBufferRow(1)).toBe(
                'sort = function () {'
              );
            });
          });
        });

        describe('when a full line was cut', () => {
          beforeEach(() => {
            editor.setCursorBufferPosition([2, 13]);
            editor.cutSelectedText();
            editor.setCursorBufferPosition([2, 13]);
          });

          it("pastes the line above the cursor and retains the cursor's column", () => {
            editor.pasteText();
            expect(editor.lineTextForBufferRow(2)).toBe(
              '    if (items.length <= 1) return items;'
            );
            expect(editor.lineTextForBufferRow(3)).toBe(
              '    var pivot = items.shift(), current, left = [], right = [];'
            );
            expect(editor.getCursorBufferPosition()).toEqual([3, 13]);
          });
        });

        describe('when a full line was copied', () => {
          beforeEach(() => {
            editor.setCursorBufferPosition([2, 13]);
            editor.copySelectedText();
          });

          describe('when there is a selection', () =>
            it('overwrites the selection as with any copied text', () => {
              editor.setSelectedBufferRange([[1, 2], [1, Infinity]]);
              editor.pasteText();
              expect(editor.lineTextForBufferRow(1)).toBe(
                '  if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(2)).toBe('');
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.getCursorBufferPosition()).toEqual([2, 0]);
            }));

          describe('when there is no selection', () =>
            it("pastes the line above the cursor and retains the cursor's column", () => {
              editor.pasteText();
              expect(editor.lineTextForBufferRow(2)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.lineTextForBufferRow(3)).toBe(
                '    if (items.length <= 1) return items;'
              );
              expect(editor.getCursorBufferPosition()).toEqual([3, 13]);
            }));
        });

        it('respects options that preserve the formatting of the pasted text', () => {
          editor.update({ autoIndentOnPaste: true });
          atom.clipboard.write('a(x);\n  b(x);\r\nc(x);\n', { indentBasis: 0 });
          editor.setCursorBufferPosition([5, 0]);
          editor.insertText('  ');
          editor.pasteText({
            autoIndent: false,
            preserveTrailingLineIndentation: true,
            normalizeLineEndings: false
          });

          expect(editor.lineTextForBufferRow(5)).toBe('  a(x);');
          expect(editor.lineTextForBufferRow(6)).toBe('  b(x);');
          expect(editor.buffer.lineEndingForRow(6)).toBe('\r\n');
          expect(editor.lineTextForBufferRow(7)).toBe('c(x);');
          expect(editor.lineTextForBufferRow(8)).toBe(
            '      current = items.shift();'
          );
        });
      });
    });

    describe('.indentSelectedRows()', () => {
      describe('when nothing is selected', () => {
        describe('when softTabs is enabled', () => {
          it('indents line and retains selection', () => {
            editor.setSelectedBufferRange([[0, 3], [0, 3]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(0)).toBe(
              '  var quicksort = function () {'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [0, 3 + editor.getTabLength()],
              [0, 3 + editor.getTabLength()]
            ]);
          });
        });

        describe('when softTabs is disabled', () => {
          it('indents line and retains selection', () => {
            convertToHardTabs(buffer);
            editor.setSoftTabs(false);
            editor.setSelectedBufferRange([[0, 3], [0, 3]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(0)).toBe(
              '\tvar quicksort = function () {'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [0, 3 + 1],
              [0, 3 + 1]
            ]);
          });
        });
      });

      describe('when one line is selected', () => {
        describe('when softTabs is enabled', () => {
          it('indents line and retains selection', () => {
            editor.setSelectedBufferRange([[0, 4], [0, 14]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(0)).toBe(
              `${editor.getTabText()}var quicksort = function () {`
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [0, 4 + editor.getTabLength()],
              [0, 14 + editor.getTabLength()]
            ]);
          });
        });

        describe('when softTabs is disabled', () => {
          it('indents line and retains selection', () => {
            convertToHardTabs(buffer);
            editor.setSoftTabs(false);
            editor.setSelectedBufferRange([[0, 4], [0, 14]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(0)).toBe(
              '\tvar quicksort = function () {'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [0, 4 + 1],
              [0, 14 + 1]
            ]);
          });
        });
      });

      describe('when multiple lines are selected', () => {
        describe('when softTabs is enabled', () => {
          it('indents selected lines (that are not empty) and retains selection', () => {
            editor.setSelectedBufferRange([[9, 1], [11, 15]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(9)).toBe('    };');
            expect(buffer.lineForRow(10)).toBe('');
            expect(buffer.lineForRow(11)).toBe(
              '    return sort(Array.apply(this, arguments));'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [9, 1 + editor.getTabLength()],
              [11, 15 + editor.getTabLength()]
            ]);
          });

          it('does not indent the last row if the selection ends at column 0', () => {
            editor.setSelectedBufferRange([[9, 1], [11, 0]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(9)).toBe('    };');
            expect(buffer.lineForRow(10)).toBe('');
            expect(buffer.lineForRow(11)).toBe(
              '  return sort(Array.apply(this, arguments));'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [9, 1 + editor.getTabLength()],
              [11, 0]
            ]);
          });
        });

        describe('when softTabs is disabled', () => {
          it('indents selected lines (that are not empty) and retains selection', () => {
            convertToHardTabs(buffer);
            editor.setSoftTabs(false);
            editor.setSelectedBufferRange([[9, 1], [11, 15]]);
            editor.indentSelectedRows();
            expect(buffer.lineForRow(9)).toBe('\t\t};');
            expect(buffer.lineForRow(10)).toBe('');
            expect(buffer.lineForRow(11)).toBe(
              '\t\treturn sort(Array.apply(this, arguments));'
            );
            expect(editor.getSelectedBufferRange()).toEqual([
              [9, 1 + 1],
              [11, 15 + 1]
            ]);
          });
        });
      });
    });

    describe('.outdentSelectedRows()', () => {
      describe('when nothing is selected', () => {
        it('outdents line and retains selection', () => {
          editor.setSelectedBufferRange([[1, 3], [1, 3]]);
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(1)).toBe('var sort = function(items) {');
          expect(editor.getSelectedBufferRange()).toEqual([
            [1, 3 - editor.getTabLength()],
            [1, 3 - editor.getTabLength()]
          ]);
        });

        it('outdents when indent is less than a tab length', () => {
          editor.insertText(' ');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
        });

        it('outdents a single hard tab when indent is multiple hard tabs and and the session is using soft tabs', () => {
          editor.insertText('\t\t');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('\tvar quicksort = function () {');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
        });

        it('outdents when a mix of hard tabs and soft tabs are used', () => {
          editor.insertText('\t   ');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('   var quicksort = function () {');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe(' var quicksort = function () {');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
        });

        it('outdents only up to the first non-space non-tab character', () => {
          editor.insertText(' \tfoo\t ');
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe(
            '\tfoo\t var quicksort = function () {'
          );
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe(
            'foo\t var quicksort = function () {'
          );
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe(
            'foo\t var quicksort = function () {'
          );
        });
      });

      describe('when one line is selected', () => {
        it('outdents line and retains editor', () => {
          editor.setSelectedBufferRange([[1, 4], [1, 14]]);
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(1)).toBe('var sort = function(items) {');
          expect(editor.getSelectedBufferRange()).toEqual([
            [1, 4 - editor.getTabLength()],
            [1, 14 - editor.getTabLength()]
          ]);
        });
      });

      describe('when multiple lines are selected', () => {
        it('outdents selected lines and retains editor', () => {
          editor.setSelectedBufferRange([[0, 1], [3, 15]]);
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
          expect(buffer.lineForRow(1)).toBe('var sort = function(items) {');
          expect(buffer.lineForRow(2)).toBe(
            '  if (items.length <= 1) return items;'
          );
          expect(buffer.lineForRow(3)).toBe(
            '  var pivot = items.shift(), current, left = [], right = [];'
          );
          expect(editor.getSelectedBufferRange()).toEqual([
            [0, 1],
            [3, 15 - editor.getTabLength()]
          ]);
        });

        it('does not outdent the last line of the selection if it ends at column 0', () => {
          editor.setSelectedBufferRange([[0, 1], [3, 0]]);
          editor.outdentSelectedRows();
          expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
          expect(buffer.lineForRow(1)).toBe('var sort = function(items) {');
          expect(buffer.lineForRow(2)).toBe(
            '  if (items.length <= 1) return items;'
          );
          expect(buffer.lineForRow(3)).toBe(
            '    var pivot = items.shift(), current, left = [], right = [];'
          );

          expect(editor.getSelectedBufferRange()).toEqual([[0, 1], [3, 0]]);
        });
      });
    });

    describe('.autoIndentSelectedRows', () => {
      it('auto-indents the selection', () => {
        editor.setCursorBufferPosition([2, 0]);
        editor.insertText('function() {\ninside=true\n}\n  i=1\n');
        editor.getLastSelection().setBufferRange([[2, 0], [6, 0]]);
        editor.autoIndentSelectedRows();

        expect(editor.lineTextForBufferRow(2)).toBe('    function() {');
        expect(editor.lineTextForBufferRow(3)).toBe('      inside=true');
        expect(editor.lineTextForBufferRow(4)).toBe('    }');
        expect(editor.lineTextForBufferRow(5)).toBe('    i=1');
      });
    });

    describe('.undo() and .redo()', () => {
      it('undoes/redoes the last change', () => {
        editor.insertText('foo');
        editor.undo();
        expect(buffer.lineForRow(0)).not.toContain('foo');

        editor.redo();
        expect(buffer.lineForRow(0)).toContain('foo');
      });

      it('batches the undo / redo of changes caused by multiple cursors', () => {
        editor.setCursorScreenPosition([0, 0]);
        editor.addCursorAtScreenPosition([1, 0]);

        editor.insertText('foo');
        editor.backspace();

        expect(buffer.lineForRow(0)).toContain('fovar');
        expect(buffer.lineForRow(1)).toContain('fo ');

        editor.undo();

        expect(buffer.lineForRow(0)).toContain('foo');
        expect(buffer.lineForRow(1)).toContain('foo');

        editor.redo();

        expect(buffer.lineForRow(0)).not.toContain('foo');
        expect(buffer.lineForRow(0)).toContain('fovar');
      });

      it('restores cursors and selections to their states before and after undone and redone changes', () => {
        editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[1, 0], [1, 3]]]);
        editor.insertText('abc');

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 3]],
          [[1, 3], [1, 3]]
        ]);

        editor.setCursorBufferPosition([0, 0]);
        editor.setSelectedBufferRanges([
          [[2, 0], [2, 0]],
          [[3, 0], [3, 0]],
          [[4, 0], [4, 3]]
        ]);
        editor.insertText('def');

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 3], [2, 3]],
          [[3, 3], [3, 3]],
          [[4, 3], [4, 3]]
        ]);

        editor.setCursorBufferPosition([0, 0]);
        editor.undo();

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 0], [2, 0]],
          [[3, 0], [3, 0]],
          [[4, 0], [4, 3]]
        ]);

        editor.undo();

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[1, 0], [1, 3]]
        ]);

        editor.redo();

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 3]],
          [[1, 3], [1, 3]]
        ]);

        editor.redo();

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[2, 3], [2, 3]],
          [[3, 3], [3, 3]],
          [[4, 3], [4, 3]]
        ]);
      });

      it('restores the selected ranges after undo and redo', () => {
        editor.setSelectedBufferRanges([[[1, 6], [1, 10]], [[1, 22], [1, 27]]]);
        editor.delete();
        editor.delete();

        expect(buffer.lineForRow(1)).toBe('  var = function( {');

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 6], [1, 6]],
          [[1, 17], [1, 17]]
        ]);

        editor.undo();
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 6], [1, 6]],
          [[1, 18], [1, 18]]
        ]);

        editor.undo();
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 6], [1, 10]],
          [[1, 22], [1, 27]]
        ]);

        editor.redo();
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 6], [1, 6]],
          [[1, 18], [1, 18]]
        ]);
      });

      xit('restores folds after undo and redo', () => {
        editor.foldBufferRow(1);
        editor.setSelectedBufferRange([[1, 0], [10, Infinity]], {
          preserveFolds: true
        });
        expect(editor.isFoldedAtBufferRow(1)).toBeTruthy();

        editor.insertText(dedent`\
          // testing
          function foo() {
            return 1 + 2;
          }\
        `);
        expect(editor.isFoldedAtBufferRow(1)).toBeFalsy();
        editor.foldBufferRow(2);

        editor.undo();
        expect(editor.isFoldedAtBufferRow(1)).toBeTruthy();
        expect(editor.isFoldedAtBufferRow(9)).toBeTruthy();
        expect(editor.isFoldedAtBufferRow(10)).toBeFalsy();

        editor.redo();
        expect(editor.isFoldedAtBufferRow(1)).toBeFalsy();
        expect(editor.isFoldedAtBufferRow(2)).toBeTruthy();
      });
    });

    describe('::transact', () => {
      it('restores the selection when the transaction is undone/redone', () => {
        buffer.setText('1234');
        editor.setSelectedBufferRange([[0, 1], [0, 3]]);

        editor.transact(() => {
          editor.delete();
          editor.moveToEndOfLine();
          editor.insertText('5');
          expect(buffer.getText()).toBe('145');
        });

        editor.undo();
        expect(buffer.getText()).toBe('1234');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 1], [0, 3]]);

        editor.redo();
        expect(buffer.getText()).toBe('145');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 3], [0, 3]]);
      });
    });

    describe('undo/redo restore selections of editor which initiated original change', () => {
      let editor1, editor2;

      beforeEach(async () => {
        editor1 = editor;
        editor2 = new TextEditor({ buffer: editor1.buffer });

        editor1.setText(dedent`
          aaaaaa
          bbbbbb
          cccccc
          dddddd
          eeeeee
        `);
      });

      it('[editor.transact] restore selection of change-initiated-editor', () => {
        editor1.setCursorBufferPosition([0, 0]);
        editor1.transact(() => editor1.insertText('1'));
        editor2.setCursorBufferPosition([1, 0]);
        editor2.transact(() => editor2.insertText('2'));
        editor1.setCursorBufferPosition([2, 0]);
        editor1.transact(() => editor1.insertText('3'));
        editor2.setCursorBufferPosition([3, 0]);
        editor2.transact(() => editor2.insertText('4'));

        expect(editor1.getText()).toBe(dedent`
          1aaaaaa
          2bbbbbb
          3cccccc
          4dddddd
          eeeeee
        `);

        editor2.setCursorBufferPosition([4, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([3, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([2, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([1, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([0, 0]);
        expect(editor2.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([0, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([1, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([2, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([3, 1]);
        expect(editor2.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor1.setCursorBufferPosition([4, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([3, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([2, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([1, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([0, 0]);
        expect(editor1.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([0, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([1, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([2, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([3, 1]);
        expect(editor1.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged
      });

      it('[manually group checkpoint] restore selection of change-initiated-editor', () => {
        const transact = (editor, fn) => {
          const checkpoint = editor.createCheckpoint();
          fn();
          editor.groupChangesSinceCheckpoint(checkpoint);
        };

        editor1.setCursorBufferPosition([0, 0]);
        transact(editor1, () => editor1.insertText('1'));
        editor2.setCursorBufferPosition([1, 0]);
        transact(editor2, () => editor2.insertText('2'));
        editor1.setCursorBufferPosition([2, 0]);
        transact(editor1, () => editor1.insertText('3'));
        editor2.setCursorBufferPosition([3, 0]);
        transact(editor2, () => editor2.insertText('4'));

        expect(editor1.getText()).toBe(dedent`
          1aaaaaa
          2bbbbbb
          3cccccc
          4dddddd
          eeeeee
        `);

        editor2.setCursorBufferPosition([4, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([3, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([2, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([1, 0]);
        editor1.undo();
        expect(editor1.getCursorBufferPosition()).toEqual([0, 0]);
        expect(editor2.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([0, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([1, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([2, 1]);
        editor1.redo();
        expect(editor1.getCursorBufferPosition()).toEqual([3, 1]);
        expect(editor2.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor1.setCursorBufferPosition([4, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([3, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([2, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([1, 0]);
        editor2.undo();
        expect(editor2.getCursorBufferPosition()).toEqual([0, 0]);
        expect(editor1.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged

        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([0, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([1, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([2, 1]);
        editor2.redo();
        expect(editor2.getCursorBufferPosition()).toEqual([3, 1]);
        expect(editor1.getCursorBufferPosition()).toEqual([4, 0]); // remain unchanged
      });
    });

    describe('when the buffer is changed (via its direct api, rather than via than edit session)', () => {
      it('moves the cursor so it is in the same relative position of the buffer', () => {
        expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
        editor.addCursorAtScreenPosition([0, 5]);
        editor.addCursorAtScreenPosition([1, 0]);
        const [cursor1, cursor2, cursor3] = editor.getCursors();

        buffer.insert([0, 1], 'abc');

        expect(cursor1.getScreenPosition()).toEqual([0, 0]);
        expect(cursor2.getScreenPosition()).toEqual([0, 8]);
        expect(cursor3.getScreenPosition()).toEqual([1, 0]);
      });

      it('does not destroy cursors or selections when a change encompasses them', () => {
        const cursor = editor.getLastCursor();
        cursor.setBufferPosition([3, 3]);
        editor.buffer.delete([[3, 1], [3, 5]]);
        expect(cursor.getBufferPosition()).toEqual([3, 1]);
        expect(editor.getCursors().indexOf(cursor)).not.toBe(-1);

        const selection = editor.getLastSelection();
        selection.setBufferRange([[3, 5], [3, 10]]);
        editor.buffer.delete([[3, 3], [3, 8]]);
        expect(selection.getBufferRange()).toEqual([[3, 3], [3, 5]]);
        expect(editor.getSelections().indexOf(selection)).not.toBe(-1);
      });

      it('merges cursors when the change causes them to overlap', () => {
        editor.setCursorScreenPosition([0, 0]);
        editor.addCursorAtScreenPosition([0, 2]);
        editor.addCursorAtScreenPosition([1, 2]);

        const [cursor1, , cursor3] = editor.getCursors();
        expect(editor.getCursors().length).toBe(3);

        buffer.delete([[0, 0], [0, 2]]);

        expect(editor.getCursors().length).toBe(2);
        expect(editor.getCursors()).toEqual([cursor1, cursor3]);
        expect(cursor1.getBufferPosition()).toEqual([0, 0]);
        expect(cursor3.getBufferPosition()).toEqual([1, 2]);
      });
    });

    describe('.moveSelectionLeft()', () => {
      it('moves one active selection on one line one column to the left', () => {
        editor.setSelectedBufferRange([[0, 4], [0, 13]]);
        expect(editor.getSelectedText()).toBe('quicksort');

        editor.moveSelectionLeft();

        expect(editor.getSelectedText()).toBe('quicksort');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 3], [0, 12]]);
      });

      it('moves multiple active selections on one line one column to the left', () => {
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]]);
        const selections = editor.getSelections();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('function');

        editor.moveSelectionLeft();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('function');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 12]],
          [[0, 15], [0, 23]]
        ]);
      });

      it('moves multiple active selections on multiple lines one column to the left', () => {
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]]);
        const selections = editor.getSelections();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('sort');

        editor.moveSelectionLeft();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('sort');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 3], [0, 12]],
          [[1, 5], [1, 9]]
        ]);
      });

      describe('when a selection is at the first column of a line', () => {
        it('does not change the selection', () => {
          editor.setSelectedBufferRanges([[[0, 0], [0, 3]], [[1, 0], [1, 3]]]);
          const selections = editor.getSelections();

          expect(selections[0].getText()).toBe('var');
          expect(selections[1].getText()).toBe('  v');

          editor.moveSelectionLeft();
          editor.moveSelectionLeft();

          expect(selections[0].getText()).toBe('var');
          expect(selections[1].getText()).toBe('  v');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[1, 0], [1, 3]]
          ]);
        });

        describe('when multiple selections are active on one line', () => {
          it('does not change the selection', () => {
            editor.setSelectedBufferRanges([
              [[0, 0], [0, 3]],
              [[0, 4], [0, 13]]
            ]);
            const selections = editor.getSelections();

            expect(selections[0].getText()).toBe('var');
            expect(selections[1].getText()).toBe('quicksort');

            editor.moveSelectionLeft();

            expect(selections[0].getText()).toBe('var');
            expect(selections[1].getText()).toBe('quicksort');
            expect(editor.getSelectedBufferRanges()).toEqual([
              [[0, 0], [0, 3]],
              [[0, 4], [0, 13]]
            ]);
          });
        });
      });
    });

    describe('.moveSelectionRight()', () => {
      it('moves one active selection on one line one column to the right', () => {
        editor.setSelectedBufferRange([[0, 4], [0, 13]]);
        expect(editor.getSelectedText()).toBe('quicksort');

        editor.moveSelectionRight();

        expect(editor.getSelectedText()).toBe('quicksort');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 5], [0, 14]]);
      });

      it('moves multiple active selections on one line one column to the right', () => {
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]]);
        const selections = editor.getSelections();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('function');

        editor.moveSelectionRight();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('function');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 5], [0, 14]],
          [[0, 17], [0, 25]]
        ]);
      });

      it('moves multiple active selections on multiple lines one column to the right', () => {
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]]);
        const selections = editor.getSelections();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('sort');

        editor.moveSelectionRight();

        expect(selections[0].getText()).toBe('quicksort');
        expect(selections[1].getText()).toBe('sort');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 5], [0, 14]],
          [[1, 7], [1, 11]]
        ]);
      });

      describe('when a selection is at the last column of a line', () => {
        it('does not change the selection', () => {
          editor.setSelectedBufferRanges([
            [[2, 34], [2, 40]],
            [[5, 22], [5, 30]]
          ]);
          const selections = editor.getSelections();

          expect(selections[0].getText()).toBe('items;');
          expect(selections[1].getText()).toBe('shift();');

          editor.moveSelectionRight();
          editor.moveSelectionRight();

          expect(selections[0].getText()).toBe('items;');
          expect(selections[1].getText()).toBe('shift();');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[2, 34], [2, 40]],
            [[5, 22], [5, 30]]
          ]);
        });

        describe('when multiple selections are active on one line', () => {
          it('does not change the selection', () => {
            editor.setSelectedBufferRanges([
              [[2, 27], [2, 33]],
              [[2, 34], [2, 40]]
            ]);
            const selections = editor.getSelections();

            expect(selections[0].getText()).toBe('return');
            expect(selections[1].getText()).toBe('items;');

            editor.moveSelectionRight();

            expect(selections[0].getText()).toBe('return');
            expect(selections[1].getText()).toBe('items;');
            expect(editor.getSelectedBufferRanges()).toEqual([
              [[2, 27], [2, 33]],
              [[2, 34], [2, 40]]
            ]);
          });
        });
      });
    });

    describe('when readonly', () => {
      beforeEach(() => {
        editor.setReadOnly(true);
      });

      const modifications = [
        {
          name: 'moveLineUp',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([1, 0]);
            editor.moveLineUp(opts);
          }
        },
        {
          name: 'moveLineDown',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([0, 0]);
            editor.moveLineDown(opts);
          }
        },
        {
          name: 'insertText',
          op: (opts = {}) => {
            editor.setSelectedBufferRange([[1, 0], [1, 2]]);
            editor.insertText('xxx', opts);
          }
        },
        {
          name: 'insertNewline',
          op: (opts = {}) => {
            editor.setCursorScreenPosition({ row: 1, column: 0 });
            editor.insertNewline(opts);
          }
        },
        {
          name: 'insertNewlineBelow',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([0, 2]);
            editor.insertNewlineBelow(opts);
          }
        },
        {
          name: 'insertNewlineAbove',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([0]);
            editor.insertNewlineAbove(opts);
          }
        },
        {
          name: 'backspace',
          op: (opts = {}) => {
            editor.setCursorScreenPosition({ row: 1, column: 7 });
            editor.backspace(opts);
          }
        },
        {
          name: 'deleteToPreviousWordBoundary',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([0, 16]);
            editor.deleteToPreviousWordBoundary(opts);
          }
        },
        {
          name: 'deleteToNextWordBoundary',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([0, 15]);
            editor.deleteToNextWordBoundary(opts);
          }
        },
        {
          name: 'deleteToBeginningOfWord',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([1, 24]);
            editor.deleteToBeginningOfWord(opts);
          }
        },
        {
          name: 'deleteToEndOfLine',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([1, 24]);
            editor.deleteToEndOfLine(opts);
          }
        },
        {
          name: 'deleteToBeginningOfLine',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([1, 24]);
            editor.deleteToBeginningOfLine(opts);
          }
        },
        {
          name: 'delete',
          op: (opts = {}) => {
            editor.setCursorScreenPosition([1, 6]);
            editor.delete(opts);
          }
        },
        {
          name: 'deleteToEndOfWord',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([1, 24]);
            editor.deleteToEndOfWord(opts);
          }
        },
        {
          name: 'indent',
          op: (opts = {}) => {
            editor.indent(opts);
          }
        },
        {
          name: 'cutSelectedText',
          op: (opts = {}) => {
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]]
            ]);
            editor.cutSelectedText(opts);
          }
        },
        {
          name: 'cutToEndOfLine',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([2, 20]);
            editor.cutToEndOfLine(opts);
          }
        },
        {
          name: 'cutToEndOfBufferLine',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([2, 20]);
            editor.cutToEndOfBufferLine(opts);
          }
        },
        {
          name: 'pasteText',
          op: (opts = {}) => {
            editor.setSelectedBufferRanges([
              [[0, 4], [0, 13]],
              [[1, 6], [1, 10]]
            ]);
            atom.clipboard.write('first');
            editor.pasteText(opts);
          }
        },
        {
          name: 'indentSelectedRows',
          op: (opts = {}) => {
            editor.setSelectedBufferRange([[0, 3], [0, 3]]);
            editor.indentSelectedRows(opts);
          }
        },
        {
          name: 'outdentSelectedRows',
          op: (opts = {}) => {
            editor.setSelectedBufferRange([[1, 3], [1, 3]]);
            editor.outdentSelectedRows(opts);
          }
        },
        {
          name: 'autoIndentSelectedRows',
          op: (opts = {}) => {
            editor.setCursorBufferPosition([2, 0]);
            editor.insertText('function() {\ninside=true\n}\n  i=1\n', opts);
            editor.getLastSelection().setBufferRange([[2, 0], [6, 0]]);
            editor.autoIndentSelectedRows(opts);
          }
        },
        {
          name: 'undo/redo',
          op: (opts = {}) => {
            editor.insertText('foo', opts);
            editor.undo(opts);
            editor.redo(opts);
          }
        }
      ];

      describe('without bypassReadOnly', () => {
        for (const { name, op } of modifications) {
          it(`throws an error on ${name}`, () => {
            expect(op).toThrow();
          });
        }
      });

      describe('with bypassReadOnly', () => {
        for (const { name, op } of modifications) {
          it(`permits ${name}`, () => {
            op({ bypassReadOnly: true });
          });
        }
      });
    });
  });

  describe('reading text', () => {
    it('.lineTextForScreenRow(row)', () => {
      editor.foldBufferRow(4);
      expect(editor.lineTextForScreenRow(5)).toEqual(
        '    return sort(left).concat(pivot).concat(sort(right));'
      );
      expect(editor.lineTextForScreenRow(9)).toEqual('};');
      expect(editor.lineTextForScreenRow(10)).toBeUndefined();
    });
  });

  describe('.deleteLine()', () => {
    it('deletes the first line when the cursor is there', () => {
      editor.getLastCursor().moveToTop();
      const line1 = buffer.lineForRow(1);
      const count = buffer.getLineCount();
      expect(buffer.lineForRow(0)).not.toBe(line1);
      editor.deleteLine();
      expect(buffer.lineForRow(0)).toBe(line1);
      expect(buffer.getLineCount()).toBe(count - 1);
    });

    it('deletes the last line when the cursor is there', () => {
      const count = buffer.getLineCount();
      const secondToLastLine = buffer.lineForRow(count - 2);
      expect(buffer.lineForRow(count - 1)).not.toBe(secondToLastLine);
      editor.getLastCursor().moveToBottom();
      editor.deleteLine();
      const newCount = buffer.getLineCount();
      expect(buffer.lineForRow(newCount - 1)).toBe(secondToLastLine);
      expect(newCount).toBe(count - 1);
    });

    it('deletes whole lines when partial lines are selected', () => {
      editor.setSelectedBufferRange([[0, 2], [1, 2]]);
      const line2 = buffer.lineForRow(2);
      const count = buffer.getLineCount();
      expect(buffer.lineForRow(0)).not.toBe(line2);
      expect(buffer.lineForRow(1)).not.toBe(line2);
      editor.deleteLine();
      expect(buffer.lineForRow(0)).toBe(line2);
      expect(buffer.getLineCount()).toBe(count - 2);
    });

    it('restores cursor position for multiple cursors', () => {
      const line = '0123456789'.repeat(8);
      editor.setText((line + '\n').repeat(5));
      editor.setCursorScreenPosition([0, 5]);
      editor.addCursorAtScreenPosition([2, 8]);
      editor.deleteLine();

      const cursors = editor.getCursors();
      expect(cursors.length).toBe(2);
      expect(cursors[0].getScreenPosition()).toEqual([0, 5]);
      expect(cursors[1].getScreenPosition()).toEqual([1, 8]);
    });

    it('restores cursor position for multiple selections', () => {
      const line = '0123456789'.repeat(8);
      editor.setText((line + '\n').repeat(5));
      editor.setSelectedBufferRanges([[[0, 5], [0, 8]], [[2, 4], [2, 15]]]);
      editor.deleteLine();

      const cursors = editor.getCursors();
      expect(cursors.length).toBe(2);
      expect(cursors[0].getScreenPosition()).toEqual([0, 5]);
      expect(cursors[1].getScreenPosition()).toEqual([1, 4]);
    });

    it('deletes a line only once when multiple selections are on the same line', () => {
      const line1 = buffer.lineForRow(1);
      const count = buffer.getLineCount();
      editor.setSelectedBufferRanges([[[0, 1], [0, 2]], [[0, 4], [0, 5]]]);
      expect(buffer.lineForRow(0)).not.toBe(line1);

      editor.deleteLine();

      expect(buffer.lineForRow(0)).toBe(line1);
      expect(buffer.getLineCount()).toBe(count - 1);
    });

    it('only deletes first line if only newline is selected on second line', () => {
      editor.setSelectedBufferRange([[0, 2], [1, 0]]);
      const line1 = buffer.lineForRow(1);
      const count = buffer.getLineCount();
      expect(buffer.lineForRow(0)).not.toBe(line1);
      editor.deleteLine();
      expect(buffer.lineForRow(0)).toBe(line1);
      expect(buffer.getLineCount()).toBe(count - 1);
    });

    it('deletes the entire region when invoke on a folded region', () => {
      editor.foldBufferRow(1);
      editor.getLastCursor().moveToTop();
      editor.getLastCursor().moveDown();
      expect(buffer.getLineCount()).toBe(13);
      editor.deleteLine();
      expect(buffer.getLineCount()).toBe(4);
    });

    it('deletes the entire file from the bottom up', () => {
      const count = buffer.getLineCount();
      expect(count).toBeGreaterThan(0);
      for (let i = 0; i < count; i++) {
        editor.getLastCursor().moveToBottom();
        editor.deleteLine();
      }
      expect(buffer.getLineCount()).toBe(1);
      expect(buffer.getText()).toBe('');
    });

    it('deletes the entire file from the top down', () => {
      const count = buffer.getLineCount();
      expect(count).toBeGreaterThan(0);
      for (let i = 0; i < count; i++) {
        editor.getLastCursor().moveToTop();
        editor.deleteLine();
      }
      expect(buffer.getLineCount()).toBe(1);
      expect(buffer.getText()).toBe('');
    });

    describe('when soft wrap is enabled', () => {
      it('deletes the entire line that the cursor is on', () => {
        editor.setSoftWrapped(true);
        editor.setEditorWidthInChars(10);
        editor.setCursorBufferPosition([6]);

        const line7 = buffer.lineForRow(7);
        const count = buffer.getLineCount();
        expect(buffer.lineForRow(6)).not.toBe(line7);
        editor.deleteLine();
        expect(buffer.lineForRow(6)).toBe(line7);
        expect(buffer.getLineCount()).toBe(count - 1);
      });
    });

    describe('when the line being deleted precedes a fold, and the command is undone', () => {
      it('restores the line and preserves the fold', () => {
        editor.setCursorBufferPosition([4]);
        editor.foldCurrentRow();
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy();
        editor.setCursorBufferPosition([3]);
        editor.deleteLine();
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy();
        expect(buffer.lineForRow(3)).toBe('    while(items.length > 0) {');
        editor.undo();
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy();
        expect(buffer.lineForRow(3)).toBe(
          '    var pivot = items.shift(), current, left = [], right = [];'
        );
      });
    });
  });

  describe('.replaceSelectedText(options, fn)', () => {
    describe('when no text is selected', () => {
      it('inserts the text returned from the function at the cursor position', () => {
        editor.replaceSelectedText({}, () => '123');
        expect(buffer.lineForRow(0)).toBe('123var quicksort = function () {');

        editor.setCursorBufferPosition([0]);
        editor.replaceSelectedText({ selectWordIfEmpty: true }, () => 'var');
        expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');

        editor.setCursorBufferPosition([10]);
        editor.replaceSelectedText(null, () => '');
        expect(buffer.lineForRow(10)).toBe('');
      });
    });

    describe('when text is selected', () => {
      it('replaces the selected text with the text returned from the function', () => {
        editor.setSelectedBufferRange([[0, 1], [0, 3]]);
        editor.replaceSelectedText({}, () => 'ia');
        expect(buffer.lineForRow(0)).toBe('via quicksort = function () {');
      });

      it('replaces the selected text and selects the replacement text', () => {
        editor.setSelectedBufferRange([[0, 4], [0, 9]]);
        editor.replaceSelectedText({}, () => 'whatnot');
        expect(buffer.lineForRow(0)).toBe('var whatnotsort = function () {');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 4], [0, 11]]);
      });
    });
  });

  describe('.transpose()', () => {
    it('swaps two characters', () => {
      editor.buffer.setText('abc');
      editor.setCursorScreenPosition([0, 1]);
      editor.transpose();
      expect(editor.lineTextForBufferRow(0)).toBe('bac');
    });

    it('reverses a selection', () => {
      editor.buffer.setText('xabcz');
      editor.setSelectedBufferRange([[0, 1], [0, 4]]);
      editor.transpose();
      expect(editor.lineTextForBufferRow(0)).toBe('xcbaz');
    });
  });

  describe('.upperCase()', () => {
    describe('when there is no selection', () => {
      it('upper cases the current word', () => {
        editor.buffer.setText('aBc');
        editor.setCursorScreenPosition([0, 1]);
        editor.upperCase();
        expect(editor.lineTextForBufferRow(0)).toBe('ABC');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 3]]);
      });
    });

    describe('when there is a selection', () => {
      it('upper cases the current selection', () => {
        editor.buffer.setText('abc');
        editor.setSelectedBufferRange([[0, 0], [0, 2]]);
        editor.upperCase();
        expect(editor.lineTextForBufferRow(0)).toBe('ABc');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 2]]);
      });
    });
  });

  describe('.lowerCase()', () => {
    describe('when there is no selection', () => {
      it('lower cases the current word', () => {
        editor.buffer.setText('aBC');
        editor.setCursorScreenPosition([0, 1]);
        editor.lowerCase();
        expect(editor.lineTextForBufferRow(0)).toBe('abc');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 3]]);
      });
    });

    describe('when there is a selection', () => {
      it('lower cases the current selection', () => {
        editor.buffer.setText('ABC');
        editor.setSelectedBufferRange([[0, 0], [0, 2]]);
        editor.lowerCase();
        expect(editor.lineTextForBufferRow(0)).toBe('abC');
        expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 2]]);
      });
    });
  });

  describe('.setTabLength(tabLength)', () => {
    it('clips atomic soft tabs to the given tab length', () => {
      expect(editor.getTabLength()).toBe(2);
      expect(
        editor.clipScreenPosition([5, 1], { clipDirection: 'forward' })
      ).toEqual([5, 2]);

      editor.setTabLength(6);
      expect(editor.getTabLength()).toBe(6);
      expect(
        editor.clipScreenPosition([5, 1], { clipDirection: 'forward' })
      ).toEqual([5, 6]);

      const changeHandler = jasmine.createSpy('changeHandler');
      editor.onDidChange(changeHandler);
      editor.setTabLength(6);
      expect(changeHandler).not.toHaveBeenCalled();
    });

    it('does not change its tab length when the given tab length is null', () => {
      editor.setTabLength(4);
      editor.setTabLength(null);
      expect(editor.getTabLength()).toBe(4);
    });
  });

  describe('.indentLevelForLine(line)', () => {
    it('returns the indent level when the line has only leading whitespace', () => {
      expect(editor.indentLevelForLine('    hello')).toBe(2);
      expect(editor.indentLevelForLine('   hello')).toBe(1.5);
    });

    it('returns the indent level when the line has only leading tabs', () =>
      expect(editor.indentLevelForLine('\t\thello')).toBe(2));

    it('returns the indent level based on the character starting the line when the leading whitespace contains both spaces and tabs', () => {
      expect(editor.indentLevelForLine('\t  hello')).toBe(2);
      expect(editor.indentLevelForLine('  \thello')).toBe(2);
      expect(editor.indentLevelForLine('  \t hello')).toBe(2.5);
      expect(editor.indentLevelForLine('    \t \thello')).toBe(4);
      expect(editor.indentLevelForLine('     \t \thello')).toBe(4);
      expect(editor.indentLevelForLine('     \t \t hello')).toBe(4.5);
    });
  });

  describe("when the buffer's language mode changes", () => {
    beforeEach(() => {
      atom.config.set('core.useTreeSitterParsers', false);
    });

    it('notifies onDidTokenize observers when retokenization is finished', async () => {
      // Exercise the full `tokenizeInBackground` code path, which bails out early if
      // `.setVisible` has not been called with `true`.
      jasmine.unspy(TextMateLanguageMode.prototype, 'tokenizeInBackground');
      jasmine.attachToDOM(editor.getElement());

      const events = [];
      editor.onDidTokenize(event => events.push(event));

      await atom.packages.activatePackage('language-c');
      expect(
        atom.grammars.assignLanguageMode(editor.getBuffer(), 'source.c')
      ).toBe(true);
      advanceClock(1);
      expect(events.length).toBe(1);
    });

    it('notifies onDidChangeGrammar observers', async () => {
      const events = [];
      editor.onDidChangeGrammar(grammar => events.push(grammar));

      await atom.packages.activatePackage('language-c');
      expect(
        atom.grammars.assignLanguageMode(editor.getBuffer(), 'source.c')
      ).toBe(true);
      expect(events.length).toBe(1);
      expect(events[0].name).toBe('C');
    });
  });

  describe('editor.autoIndent', () => {
    describe('when editor.autoIndent is false (default)', () => {
      describe('when `indent` is triggered', () => {
        it('does not auto-indent the line', () => {
          editor.setCursorBufferPosition([1, 30]);
          editor.insertText('\n ');
          expect(editor.lineTextForBufferRow(2)).toBe(' ');

          editor.update({ autoIndent: false });
          editor.indent();
          expect(editor.lineTextForBufferRow(2)).toBe('  ');
        });
      });
    });

    describe('when editor.autoIndent is true', () => {
      beforeEach(() => editor.update({ autoIndent: true }));

      describe('when `indent` is triggered', () => {
        it('auto-indents the line', () => {
          editor.setCursorBufferPosition([1, 30]);
          editor.insertText('\n ');
          expect(editor.lineTextForBufferRow(2)).toBe(' ');

          editor.update({ autoIndent: true });
          editor.indent();
          expect(editor.lineTextForBufferRow(2)).toBe('    ');
        });
      });

      describe('when a newline is added', () => {
        describe('when the line preceding the newline adds a new level of indentation', () => {
          it('indents the newline to one additional level of indentation beyond the preceding line', () => {
            editor.setCursorBufferPosition([1, Infinity]);
            editor.insertText('\n');
            expect(editor.indentationForBufferRow(2)).toBe(
              editor.indentationForBufferRow(1) + 1
            );
          });
        });

        describe("when the line preceding the newline doesn't add a level of indentation", () => {
          it('indents the new line to the same level as the preceding line', () => {
            editor.setCursorBufferPosition([5, 14]);
            editor.insertText('\n');
            expect(editor.indentationForBufferRow(6)).toBe(
              editor.indentationForBufferRow(5)
            );
          });
        });

        describe('when the line preceding the newline is a comment', () => {
          it('maintains the indent of the commented line', () => {
            editor.setCursorBufferPosition([0, 0]);
            editor.insertText('    //');
            editor.setCursorBufferPosition([0, Infinity]);
            editor.insertText('\n');
            expect(editor.indentationForBufferRow(1)).toBe(2);
          });
        });

        describe('when the line preceding the newline contains only whitespace', () => {
          it("bases the new line's indentation on only the preceding line", () => {
            editor.setCursorBufferPosition([6, Infinity]);
            editor.insertText('\n  ');
            expect(editor.getCursorBufferPosition()).toEqual([7, 2]);

            editor.insertNewline();
            expect(editor.lineTextForBufferRow(8)).toBe('  ');
          });
        });

        it('does not indent the line preceding the newline', () => {
          editor.setCursorBufferPosition([2, 0]);
          editor.insertText('  var this-line-should-be-indented-more\n');
          expect(editor.indentationForBufferRow(1)).toBe(1);

          editor.update({ autoIndent: true });
          editor.setCursorBufferPosition([2, Infinity]);
          editor.insertText('\n');
          expect(editor.indentationForBufferRow(1)).toBe(1);
          expect(editor.indentationForBufferRow(2)).toBe(1);
        });

        describe('when the cursor is before whitespace', () => {
          it('retains the whitespace following the cursor on the new line', () => {
            editor.setText('  var sort = function() {}');
            editor.setCursorScreenPosition([0, 12]);
            editor.insertNewline();

            expect(buffer.lineForRow(0)).toBe('  var sort =');
            expect(buffer.lineForRow(1)).toBe('   function() {}');
            expect(editor.getCursorScreenPosition()).toEqual([1, 2]);
          });
        });
      });

      describe('when inserted text matches a decrease indent pattern', () => {
        describe('when the preceding line matches an increase indent pattern', () => {
          it('decreases the indentation to match that of the preceding line', () => {
            editor.setCursorBufferPosition([1, Infinity]);
            editor.insertText('\n');
            expect(editor.indentationForBufferRow(2)).toBe(
              editor.indentationForBufferRow(1) + 1
            );
            editor.insertText('}');
            expect(editor.indentationForBufferRow(2)).toBe(
              editor.indentationForBufferRow(1)
            );
          });
        });

        describe("when the preceding line doesn't match an increase indent pattern", () => {
          it('decreases the indentation to be one level below that of the preceding line', () => {
            editor.setCursorBufferPosition([3, Infinity]);
            editor.insertText('\n    ');
            expect(editor.indentationForBufferRow(4)).toBe(
              editor.indentationForBufferRow(3)
            );
            editor.insertText('}');
            expect(editor.indentationForBufferRow(4)).toBe(
              editor.indentationForBufferRow(3) - 1
            );
          });

          it("doesn't break when decreasing the indentation on a row that has no indentation", () => {
            editor.setCursorBufferPosition([12, Infinity]);
            editor.insertText('\n}; # too many closing brackets!');
            expect(editor.lineTextForBufferRow(13)).toBe(
              '}; # too many closing brackets!'
            );
          });
        });
      });

      describe('when inserted text does not match a decrease indent pattern', () => {
        it('does not decrease the indentation', () => {
          editor.setCursorBufferPosition([12, 0]);
          editor.insertText('  ');
          expect(editor.lineTextForBufferRow(12)).toBe('  };');
          editor.insertText('\t\t');
          expect(editor.lineTextForBufferRow(12)).toBe('  \t\t};');
        });
      });

      describe('when the current line does not match a decrease indent pattern', () => {
        it('leaves the line unchanged', () => {
          editor.setCursorBufferPosition([2, 4]);
          expect(editor.indentationForBufferRow(2)).toBe(
            editor.indentationForBufferRow(1) + 1
          );
          editor.insertText('foo');
          expect(editor.indentationForBufferRow(2)).toBe(
            editor.indentationForBufferRow(1) + 1
          );
        });
      });
    });
  });

  describe('atomic soft tabs', () => {
    it('skips tab-length runs of leading whitespace when moving the cursor', () => {
      editor.update({ tabLength: 4, atomicSoftTabs: true });

      editor.setCursorScreenPosition([2, 3]);
      expect(editor.getCursorScreenPosition()).toEqual([2, 4]);

      editor.update({ atomicSoftTabs: false });
      editor.setCursorScreenPosition([2, 3]);
      expect(editor.getCursorScreenPosition()).toEqual([2, 3]);

      editor.update({ atomicSoftTabs: true });
      editor.setCursorScreenPosition([2, 3]);
      expect(editor.getCursorScreenPosition()).toEqual([2, 4]);
    });
  });

  describe('.destroy()', () => {
    it('destroys marker layers associated with the text editor', () => {
      buffer.retain();
      const selectionsMarkerLayerId = editor.selectionsMarkerLayer.id;
      const foldsMarkerLayerId = editor.displayLayer.foldsMarkerLayer.id;
      editor.destroy();
      expect(buffer.getMarkerLayer(selectionsMarkerLayerId)).toBeUndefined();
      expect(buffer.getMarkerLayer(foldsMarkerLayerId)).toBeUndefined();
      buffer.release();
    });

    it('notifies ::onDidDestroy observers when the editor is destroyed', () => {
      let destroyObserverCalled = false;
      editor.onDidDestroy(() => (destroyObserverCalled = true));

      editor.destroy();
      expect(destroyObserverCalled).toBe(true);
    });

    it('does not blow up when query methods are called afterward', () => {
      editor.destroy();
      editor.getGrammar();
      editor.getLastCursor();
      editor.lineTextForBufferRow(0);
    });

    it("emits the destroy event after destroying the editor's buffer", () => {
      const events = [];
      editor.getBuffer().onDidDestroy(() => {
        expect(editor.isDestroyed()).toBe(true);
        events.push('buffer-destroyed');
      });
      editor.onDidDestroy(() => {
        expect(buffer.isDestroyed()).toBe(true);
        events.push('editor-destroyed');
      });
      editor.destroy();
      expect(events).toEqual(['buffer-destroyed', 'editor-destroyed']);
    });
  });

  describe('.joinLines()', () => {
    describe('when no text is selected', () => {
      describe("when the line below isn't empty", () => {
        it('joins the line below with the current line separated by a space and moves the cursor to the start of line that was moved up', () => {
          editor.setCursorBufferPosition([0, Infinity]);
          editor.insertText('  ');
          editor.setCursorBufferPosition([0]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(0)).toBe(
            'var quicksort = function () { var sort = function(items) {'
          );
          expect(editor.getCursorBufferPosition()).toEqual([0, 29]);
        });
      });

      describe('when the line below is empty', () => {
        it('deletes the line below and moves the cursor to the end of the line', () => {
          editor.setCursorBufferPosition([9]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(9)).toBe('  };');
          expect(editor.lineTextForBufferRow(10)).toBe(
            '  return sort(Array.apply(this, arguments));'
          );
          expect(editor.getCursorBufferPosition()).toEqual([9, 4]);
        });
      });

      describe('when the cursor is on the last row', () => {
        it('does nothing', () => {
          editor.setCursorBufferPosition([Infinity, Infinity]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(12)).toBe('};');
        });
      });

      describe('when the line is empty', () => {
        it('joins the line below with the current line with no added space', () => {
          editor.setCursorBufferPosition([10]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(10)).toBe(
            'return sort(Array.apply(this, arguments));'
          );
          expect(editor.getCursorBufferPosition()).toEqual([10, 0]);
        });
      });
    });

    describe('when text is selected', () => {
      describe('when the selection does not span multiple lines', () => {
        it('joins the line below with the current line separated by a space and retains the selected text', () => {
          editor.setSelectedBufferRange([[0, 1], [0, 3]]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(0)).toBe(
            'var quicksort = function () { var sort = function(items) {'
          );
          expect(editor.getSelectedBufferRange()).toEqual([[0, 1], [0, 3]]);
        });
      });

      describe('when the selection spans multiple lines', () => {
        it('joins all selected lines separated by a space and retains the selected text', () => {
          editor.setSelectedBufferRange([[9, 3], [12, 1]]);
          editor.joinLines();
          expect(editor.lineTextForBufferRow(9)).toBe(
            '  }; return sort(Array.apply(this, arguments)); };'
          );
          expect(editor.getSelectedBufferRange()).toEqual([[9, 3], [9, 49]]);
        });
      });
    });
  });

  describe('.duplicateLines()', () => {
    it('for each selection, duplicates all buffer lines intersected by the selection', () => {
      editor.foldBufferRow(4);
      editor.setCursorBufferPosition([2, 5]);
      editor.addSelectionForBufferRange([[3, 0], [8, 0]], {
        preserveFolds: true
      });

      editor.duplicateLines();

      expect(editor.getTextInBufferRange([[2, 0], [13, 5]])).toBe(
        dedent`
        if (items.length <= 1) return items;
        if (items.length <= 1) return items;
        var pivot = items.shift(), current, left = [], right = [];
        while(items.length > 0) {
          current = items.shift();
          current < pivot ? left.push(current) : right.push(current);
        }
        var pivot = items.shift(), current, left = [], right = [];
        while(items.length > 0) {
          current = items.shift();
          current < pivot ? left.push(current) : right.push(current);
        }\
      `
          .split('\n')
          .map(l => `    ${l}`)
          .join('\n')
      );
      expect(editor.getSelectedBufferRanges()).toEqual([
        [[3, 5], [3, 5]],
        [[9, 0], [14, 0]]
      ]);

      // folds are also duplicated
      expect(editor.isFoldedAtScreenRow(5)).toBe(true);
      expect(editor.isFoldedAtScreenRow(7)).toBe(true);
      expect(editor.lineTextForScreenRow(7)).toBe(
        `    while(items.length > 0) {${editor.displayLayer.foldCharacter}}`
      );
      expect(editor.lineTextForScreenRow(8)).toBe(
        '    return sort(left).concat(pivot).concat(sort(right));'
      );
    });

    it('duplicates all folded lines for empty selections on lines containing folds', () => {
      editor.foldBufferRow(4);
      editor.setCursorBufferPosition([4, 0]);

      editor.duplicateLines();

      expect(editor.getTextInBufferRange([[2, 0], [11, 5]])).toBe(
        dedent`
        if (items.length <= 1) return items;
        var pivot = items.shift(), current, left = [], right = [];
        while(items.length > 0) {
          current = items.shift();
          current < pivot ? left.push(current) : right.push(current);
        }
        while(items.length > 0) {
          current = items.shift();
          current < pivot ? left.push(current) : right.push(current);
        }
      `
          .split('\n')
          .map(l => `    ${l}`)
          .join('\n')
      );
      expect(editor.getSelectedBufferRange()).toEqual([[8, 0], [8, 0]]);
    });

    it('can duplicate the last line of the buffer', () => {
      editor.setSelectedBufferRange([[11, 0], [12, 2]]);
      editor.duplicateLines();
      expect(editor.getTextInBufferRange([[11, 0], [14, 2]])).toBe(
        '  ' +
          dedent`
          return sort(Array.apply(this, arguments));
        };
          return sort(Array.apply(this, arguments));
        };
      `.trim()
      );
      expect(editor.getSelectedBufferRange()).toEqual([[13, 0], [14, 2]]);
    });

    it('only duplicates lines containing multiple selections once', () => {
      editor.setText(dedent`
        aaaaaa
        bbbbbb
        cccccc
        dddddd
      `);
      editor.setSelectedBufferRanges([
        [[0, 1], [0, 2]],
        [[0, 3], [0, 4]],
        [[2, 1], [2, 2]],
        [[2, 3], [3, 1]],
        [[3, 3], [3, 4]]
      ]);
      editor.duplicateLines();
      expect(editor.getText()).toBe(dedent`
        aaaaaa
        aaaaaa
        bbbbbb
        cccccc
        dddddd
        cccccc
        dddddd
      `);
      expect(editor.getSelectedBufferRanges()).toEqual([
        [[1, 1], [1, 2]],
        [[1, 3], [1, 4]],
        [[5, 1], [5, 2]],
        [[5, 3], [6, 1]],
        [[6, 3], [6, 4]]
      ]);
    });
  });

  describe('when the editor contains surrogate pair characters', () => {
    it('correctly backspaces over them', () => {
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97');
      editor.moveToBottom();
      editor.backspace();
      expect(editor.getText()).toBe('\uD835\uDF97\uD835\uDF97');
      editor.backspace();
      expect(editor.getText()).toBe('\uD835\uDF97');
      editor.backspace();
      expect(editor.getText()).toBe('');
    });

    it('correctly deletes over them', () => {
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97');
      editor.moveToTop();
      editor.delete();
      expect(editor.getText()).toBe('\uD835\uDF97\uD835\uDF97');
      editor.delete();
      expect(editor.getText()).toBe('\uD835\uDF97');
      editor.delete();
      expect(editor.getText()).toBe('');
    });

    it('correctly moves over them', () => {
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97\n');
      editor.moveToTop();
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 6]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 6]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
    });
  });

  describe('when the editor contains variation sequence character pairs', () => {
    it('correctly backspaces over them', () => {
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E');
      editor.moveToBottom();
      editor.backspace();
      expect(editor.getText()).toBe('\u2714\uFE0E\u2714\uFE0E');
      editor.backspace();
      expect(editor.getText()).toBe('\u2714\uFE0E');
      editor.backspace();
      expect(editor.getText()).toBe('');
    });

    it('correctly deletes over them', () => {
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E');
      editor.moveToTop();
      editor.delete();
      expect(editor.getText()).toBe('\u2714\uFE0E\u2714\uFE0E');
      editor.delete();
      expect(editor.getText()).toBe('\u2714\uFE0E');
      editor.delete();
      expect(editor.getText()).toBe('');
    });

    it('correctly moves over them', () => {
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E\n');
      editor.moveToTop();
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([0, 6]);
      editor.moveRight();
      expect(editor.getCursorBufferPosition()).toEqual([1, 0]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 6]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 4]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 2]);
      editor.moveLeft();
      expect(editor.getCursorBufferPosition()).toEqual([0, 0]);
    });
  });

  describe('.setIndentationForBufferRow', () => {
    describe('when the editor uses soft tabs but the row has hard tabs', () => {
      it('only replaces whitespace characters', () => {
        editor.setSoftWrapped(true);
        editor.setText('\t1\n\t2');
        editor.setCursorBufferPosition([0, 0]);
        editor.setIndentationForBufferRow(0, 2);
        expect(editor.getText()).toBe('    1\n\t2');
      });
    });

    describe('when the indentation level is a non-integer', () => {
      it('does not throw an exception', () => {
        editor.setSoftWrapped(true);
        editor.setText('\t1\n\t2');
        editor.setCursorBufferPosition([0, 0]);
        editor.setIndentationForBufferRow(0, 2.1);
        expect(editor.getText()).toBe('    1\n\t2');
      });
    });
  });

  describe("when the editor's grammar has an injection selector", () => {
    beforeEach(async () => {
      atom.config.set('core.useTreeSitterParsers', false);
      await atom.packages.activatePackage('language-text');
      await atom.packages.activatePackage('language-javascript');
    });

    it("includes the grammar's patterns when the selector matches the current scope in other grammars", async () => {
      await atom.packages.activatePackage('language-hyperlink');

      const grammar = atom.grammars.selectGrammar('text.js');
      const { line, tags } = grammar.tokenizeLine(
        'var i; // http://github.com'
      );

      const tokens = atom.grammars.decodeTokens(line, tags);
      expect(tokens[0].value).toBe('var');
      expect(tokens[0].scopes).toEqual(['source.js', 'storage.type.var.js']);
      expect(tokens[6].value).toBe('http://github.com');
      expect(tokens[6].scopes).toEqual([
        'source.js',
        'comment.line.double-slash.js',
        'markup.underline.link.http.hyperlink'
      ]);
    });

    describe('when the grammar is added', () => {
      it('retokenizes existing buffers that contain tokens that match the injection selector', async () => {
        editor = await atom.workspace.open('sample.js');
        editor.setText('// http://github.com');
        let tokens = editor.tokensForScreenRow(0);
        expect(tokens).toEqual([
          {
            text: '//',
            scopes: [
              'syntax--source syntax--js',
              'syntax--comment syntax--line syntax--double-slash syntax--js',
              'syntax--punctuation syntax--definition syntax--comment syntax--js'
            ]
          },
          {
            text: ' http://github.com',
            scopes: [
              'syntax--source syntax--js',
              'syntax--comment syntax--line syntax--double-slash syntax--js'
            ]
          }
        ]);

        await atom.packages.activatePackage('language-hyperlink');
        tokens = editor.tokensForScreenRow(0);
        expect(tokens).toEqual([
          {
            text: '//',
            scopes: [
              'syntax--source syntax--js',
              'syntax--comment syntax--line syntax--double-slash syntax--js',
              'syntax--punctuation syntax--definition syntax--comment syntax--js'
            ]
          },
          {
            text: ' ',
            scopes: [
              'syntax--source syntax--js',
              'syntax--comment syntax--line syntax--double-slash syntax--js'
            ]
          },
          {
            text: 'http://github.com',
            scopes: [
              'syntax--source syntax--js',
              'syntax--comment syntax--line syntax--double-slash syntax--js',
              'syntax--markup syntax--underline syntax--link syntax--http syntax--hyperlink'
            ]
          }
        ]);
      });

      describe('when the grammar is updated', () => {
        it('retokenizes existing buffers that contain tokens that match the injection selector', async () => {
          editor = await atom.workspace.open('sample.js');
          editor.setText('// SELECT * FROM OCTOCATS');
          let tokens = editor.tokensForScreenRow(0);
          expect(tokens).toEqual([
            {
              text: '//',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--punctuation syntax--definition syntax--comment syntax--js'
              ]
            },
            {
              text: ' SELECT * FROM OCTOCATS',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            }
          ]);

          await atom.packages.activatePackage(
            'package-with-injection-selector'
          );
          tokens = editor.tokensForScreenRow(0);
          expect(tokens).toEqual([
            {
              text: '//',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--punctuation syntax--definition syntax--comment syntax--js'
              ]
            },
            {
              text: ' SELECT * FROM OCTOCATS',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            }
          ]);

          await atom.packages.activatePackage('language-sql');
          tokens = editor.tokensForScreenRow(0);
          expect(tokens).toEqual([
            {
              text: '//',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--punctuation syntax--definition syntax--comment syntax--js'
              ]
            },
            {
              text: ' ',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            },
            {
              text: 'SELECT',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--keyword syntax--other syntax--DML syntax--sql'
              ]
            },
            {
              text: ' ',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            },
            {
              text: '*',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--keyword syntax--operator syntax--star syntax--sql'
              ]
            },
            {
              text: ' ',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            },
            {
              text: 'FROM',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js',
                'syntax--keyword syntax--other syntax--DML syntax--sql'
              ]
            },
            {
              text: ' OCTOCATS',
              scopes: [
                'syntax--source syntax--js',
                'syntax--comment syntax--line syntax--double-slash syntax--js'
              ]
            }
          ]);
        });
      });
    });
  });

  describe('.normalizeTabsInBufferRange()', () => {
    it("normalizes tabs depending on the editor's soft tab/tab length settings", () => {
      editor.setTabLength(1);
      editor.setSoftTabs(true);
      editor.setText('\t\t\t');
      editor.normalizeTabsInBufferRange([[0, 0], [0, 1]]);
      expect(editor.getText()).toBe(' \t\t');

      editor.setTabLength(2);
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]]);
      expect(editor.getText()).toBe('     ');

      editor.setSoftTabs(false);
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]]);
      expect(editor.getText()).toBe('     ');
    });
  });

  describe('.pageUp/Down()', () => {
    it('moves the cursor down one page length', () => {
      editor.update({ autoHeight: false });
      const element = editor.getElement();
      jasmine.attachToDOM(element);
      element.style.height = element.component.getLineHeight() * 5 + 'px';
      element.measureDimensions();

      expect(editor.getCursorBufferPosition().row).toBe(0);

      editor.pageDown();
      expect(editor.getCursorBufferPosition().row).toBe(5);

      editor.pageDown();
      expect(editor.getCursorBufferPosition().row).toBe(10);

      editor.pageUp();
      expect(editor.getCursorBufferPosition().row).toBe(5);

      editor.pageUp();
      expect(editor.getCursorBufferPosition().row).toBe(0);
    });
  });

  describe('.selectPageUp/Down()', () => {
    it('selects one screen height of text up or down', () => {
      editor.update({ autoHeight: false });
      const element = editor.getElement();
      jasmine.attachToDOM(element);
      element.style.height = element.component.getLineHeight() * 5 + 'px';
      element.measureDimensions();

      expect(editor.getCursorBufferPosition().row).toBe(0);

      editor.selectPageDown();
      expect(editor.getSelectedBufferRanges()).toEqual([[[0, 0], [5, 0]]]);

      editor.selectPageDown();
      expect(editor.getSelectedBufferRanges()).toEqual([[[0, 0], [10, 0]]]);

      editor.selectPageDown();
      expect(editor.getSelectedBufferRanges()).toEqual([[[0, 0], [12, 2]]]);

      editor.moveToBottom();
      editor.selectPageUp();
      expect(editor.getSelectedBufferRanges()).toEqual([[[7, 0], [12, 2]]]);

      editor.selectPageUp();
      expect(editor.getSelectedBufferRanges()).toEqual([[[2, 0], [12, 2]]]);

      editor.selectPageUp();
      expect(editor.getSelectedBufferRanges()).toEqual([[[0, 0], [12, 2]]]);
    });
  });

  describe('::scrollToScreenPosition(position, [options])', () => {
    it('triggers ::onDidRequestAutoscroll with the logical coordinates along with the options', () => {
      const scrollSpy = jasmine.createSpy('::onDidRequestAutoscroll');
      editor.onDidRequestAutoscroll(scrollSpy);

      editor.scrollToScreenPosition([8, 20]);
      editor.scrollToScreenPosition([8, 20], { center: true });
      editor.scrollToScreenPosition([8, 20], { center: false, reversed: true });

      expect(scrollSpy).toHaveBeenCalledWith({
        screenRange: [[8, 20], [8, 20]],
        options: {}
      });
      expect(scrollSpy).toHaveBeenCalledWith({
        screenRange: [[8, 20], [8, 20]],
        options: { center: true }
      });
      expect(scrollSpy).toHaveBeenCalledWith({
        screenRange: [[8, 20], [8, 20]],
        options: { center: false, reversed: true }
      });
    });
  });

  describe('scroll past end', () => {
    it('returns false by default but can be customized', () => {
      expect(editor.getScrollPastEnd()).toBe(false);
      editor.update({ scrollPastEnd: true });
      expect(editor.getScrollPastEnd()).toBe(true);
      editor.update({ scrollPastEnd: false });
      expect(editor.getScrollPastEnd()).toBe(false);
    });

    it('always returns false when autoHeight is on', () => {
      editor.update({ autoHeight: true, scrollPastEnd: true });
      expect(editor.getScrollPastEnd()).toBe(false);
      editor.update({ autoHeight: false });
      expect(editor.getScrollPastEnd()).toBe(true);
    });
  });

  describe('auto height', () => {
    it('returns true by default but can be customized', () => {
      editor = new TextEditor();
      expect(editor.getAutoHeight()).toBe(true);
      editor.update({ autoHeight: false });
      expect(editor.getAutoHeight()).toBe(false);
      editor.update({ autoHeight: true });
      expect(editor.getAutoHeight()).toBe(true);
      editor.destroy();
    });
  });

  describe('auto width', () => {
    it('returns false by default but can be customized', () => {
      expect(editor.getAutoWidth()).toBe(false);
      editor.update({ autoWidth: true });
      expect(editor.getAutoWidth()).toBe(true);
      editor.update({ autoWidth: false });
      expect(editor.getAutoWidth()).toBe(false);
    });
  });

  describe('.get/setPlaceholderText()', () => {
    it('can be created with placeholderText', () => {
      const newEditor = new TextEditor({
        mini: true,
        placeholderText: 'yep'
      });
      expect(newEditor.getPlaceholderText()).toBe('yep');
    });

    it('models placeholderText and emits an event when changed', () => {
      let handler;
      editor.onDidChangePlaceholderText((handler = jasmine.createSpy()));

      expect(editor.getPlaceholderText()).toBeUndefined();

      editor.setPlaceholderText('OK');
      expect(handler).toHaveBeenCalledWith('OK');
      expect(editor.getPlaceholderText()).toBe('OK');
    });
  });

  describe('gutters', () => {
    describe('the TextEditor constructor', () => {
      it('creates a line-number gutter', () => {
        expect(editor.getGutters().length).toBe(1);
        const lineNumberGutter = editor.gutterWithName('line-number');
        expect(lineNumberGutter.name).toBe('line-number');
        expect(lineNumberGutter.priority).toBe(0);
      });
    });

    describe('::addGutter', () => {
      it('can add a gutter', () => {
        expect(editor.getGutters().length).toBe(1); // line-number gutter
        const options = {
          name: 'test-gutter',
          priority: 1
        };
        const gutter = editor.addGutter(options);
        expect(editor.getGutters().length).toBe(2);
        expect(editor.getGutters()[1]).toBe(gutter);
        expect(gutter.type).toBe('decorated');
      });

      it('can add a custom line-number gutter', () => {
        expect(editor.getGutters().length).toBe(1);
        const options = {
          name: 'another-gutter',
          priority: 2,
          type: 'line-number'
        };
        const gutter = editor.addGutter(options);
        expect(editor.getGutters().length).toBe(2);
        expect(editor.getGutters()[1]).toBe(gutter);
        expect(gutter.type).toBe('line-number');
      });

      it("does not allow a custom gutter with the 'line-number' name.", () =>
        expect(
          editor.addGutter.bind(editor, { name: 'line-number' })
        ).toThrow());
    });

    describe('::decorateMarker', () => {
      let marker;

      beforeEach(() => (marker = editor.markBufferRange([[1, 0], [1, 0]])));

      it('reflects an added decoration when one of its custom gutters is decorated.', () => {
        const gutter = editor.addGutter({ name: 'custom-gutter' });
        const decoration = gutter.decorateMarker(marker, {
          class: 'custom-class'
        });
        const gutterDecorations = editor.getDecorations({
          type: 'gutter',
          gutterName: 'custom-gutter',
          class: 'custom-class'
        });
        expect(gutterDecorations.length).toBe(1);
        expect(gutterDecorations[0]).toBe(decoration);
      });

      it('reflects an added decoration when its line-number gutter is decorated.', () => {
        const decoration = editor
          .gutterWithName('line-number')
          .decorateMarker(marker, { class: 'test-class' });
        const gutterDecorations = editor.getDecorations({
          type: 'line-number',
          gutterName: 'line-number',
          class: 'test-class'
        });
        expect(gutterDecorations.length).toBe(1);
        expect(gutterDecorations[0]).toBe(decoration);
      });
    });

    describe('::observeGutters', () => {
      let payloads, callback;

      beforeEach(() => {
        payloads = [];
        callback = payload => payloads.push(payload);
      });

      it('calls the callback immediately with each existing gutter, and with each added gutter after that.', () => {
        const lineNumberGutter = editor.gutterWithName('line-number');
        editor.observeGutters(callback);
        expect(payloads).toEqual([lineNumberGutter]);
        const gutter1 = editor.addGutter({ name: 'test-gutter-1' });
        expect(payloads).toEqual([lineNumberGutter, gutter1]);
        const gutter2 = editor.addGutter({ name: 'test-gutter-2' });
        expect(payloads).toEqual([lineNumberGutter, gutter1, gutter2]);
      });

      it('does not call the callback when a gutter is removed.', () => {
        const gutter = editor.addGutter({ name: 'test-gutter' });
        editor.observeGutters(callback);
        payloads = [];
        gutter.destroy();
        expect(payloads).toEqual([]);
      });

      it('does not call the callback after the subscription has been disposed.', () => {
        const subscription = editor.observeGutters(callback);
        payloads = [];
        subscription.dispose();
        editor.addGutter({ name: 'test-gutter' });
        expect(payloads).toEqual([]);
      });
    });

    describe('::onDidAddGutter', () => {
      let payloads, callback;

      beforeEach(() => {
        payloads = [];
        callback = payload => payloads.push(payload);
      });

      it('calls the callback with each newly-added gutter, but not with existing gutters.', () => {
        editor.onDidAddGutter(callback);
        expect(payloads).toEqual([]);
        const gutter = editor.addGutter({ name: 'test-gutter' });
        expect(payloads).toEqual([gutter]);
      });

      it('does not call the callback after the subscription has been disposed.', () => {
        const subscription = editor.onDidAddGutter(callback);
        payloads = [];
        subscription.dispose();
        editor.addGutter({ name: 'test-gutter' });
        expect(payloads).toEqual([]);
      });
    });

    describe('::onDidRemoveGutter', () => {
      let payloads, callback;

      beforeEach(() => {
        payloads = [];
        callback = payload => payloads.push(payload);
      });

      it('calls the callback when a gutter is removed.', () => {
        const gutter = editor.addGutter({ name: 'test-gutter' });
        editor.onDidRemoveGutter(callback);
        expect(payloads).toEqual([]);
        gutter.destroy();
        expect(payloads).toEqual(['test-gutter']);
      });

      it('does not call the callback after the subscription has been disposed.', () => {
        const gutter = editor.addGutter({ name: 'test-gutter' });
        const subscription = editor.onDidRemoveGutter(callback);
        subscription.dispose();
        gutter.destroy();
        expect(payloads).toEqual([]);
      });
    });
  });

  describe('decorations', () => {
    describe('::decorateMarker', () => {
      it('includes the decoration in the object returned from ::decorationsStateForScreenRowRange', () => {
        const marker = editor.markBufferRange([[2, 4], [6, 8]]);
        const decoration = editor.decorateMarker(marker, {
          type: 'highlight',
          class: 'foo'
        });
        expect(
          editor.decorationsStateForScreenRowRange(0, 5)[decoration.id]
        ).toEqual({
          properties: {
            id: decoration.id,
            order: Infinity,
            type: 'highlight',
            class: 'foo'
          },
          screenRange: marker.getScreenRange(),
          bufferRange: marker.getBufferRange(),
          rangeIsReversed: false
        });
      });

      it("does not throw errors after the marker's containing layer is destroyed", () => {
        const layer = editor.addMarkerLayer();
        layer.markBufferRange([[2, 4], [6, 8]]);

        layer.destroy();
        editor.decorationsStateForScreenRowRange(0, 5);
      });
    });

    describe('::decorateMarkerLayer', () => {
      it('based on the markers in the layer, includes multiple decoration objects with the same properties and different ranges in the object returned from ::decorationsStateForScreenRowRange', () => {
        const layer1 = editor.getBuffer().addMarkerLayer();
        const marker1 = layer1.markRange([[2, 4], [6, 8]]);
        const marker2 = layer1.markRange([[11, 0], [11, 12]]);
        const layer2 = editor.getBuffer().addMarkerLayer();
        const marker3 = layer2.markRange([[8, 0], [9, 0]]);

        const layer1Decoration1 = editor.decorateMarkerLayer(layer1, {
          type: 'highlight',
          class: 'foo'
        });
        const layer1Decoration2 = editor.decorateMarkerLayer(layer1, {
          type: 'highlight',
          class: 'bar'
        });
        const layer2Decoration = editor.decorateMarkerLayer(layer2, {
          type: 'highlight',
          class: 'baz'
        });

        let decorationState = editor.decorationsStateForScreenRowRange(0, 13);

        expect(
          decorationState[`${layer1Decoration1.id}-${marker1.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'foo' },
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        });
        expect(
          decorationState[`${layer1Decoration1.id}-${marker2.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'foo' },
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        });
        expect(
          decorationState[`${layer1Decoration2.id}-${marker1.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'bar' },
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        });
        expect(
          decorationState[`${layer1Decoration2.id}-${marker2.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'bar' },
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        });
        expect(decorationState[`${layer2Decoration.id}-${marker3.id}`]).toEqual(
          {
            properties: { type: 'highlight', class: 'baz' },
            screenRange: marker3.getRange(),
            bufferRange: marker3.getRange(),
            rangeIsReversed: false
          }
        );

        layer1Decoration1.destroy();

        decorationState = editor.decorationsStateForScreenRowRange(0, 12);
        expect(
          decorationState[`${layer1Decoration1.id}-${marker1.id}`]
        ).toBeUndefined();
        expect(
          decorationState[`${layer1Decoration1.id}-${marker2.id}`]
        ).toBeUndefined();
        expect(
          decorationState[`${layer1Decoration2.id}-${marker1.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'bar' },
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        });
        expect(
          decorationState[`${layer1Decoration2.id}-${marker2.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'bar' },
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        });
        expect(decorationState[`${layer2Decoration.id}-${marker3.id}`]).toEqual(
          {
            properties: { type: 'highlight', class: 'baz' },
            screenRange: marker3.getRange(),
            bufferRange: marker3.getRange(),
            rangeIsReversed: false
          }
        );

        layer1Decoration2.setPropertiesForMarker(marker1, {
          type: 'highlight',
          class: 'quux'
        });
        decorationState = editor.decorationsStateForScreenRowRange(0, 12);
        expect(
          decorationState[`${layer1Decoration2.id}-${marker1.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'quux' },
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        });

        layer1Decoration2.setPropertiesForMarker(marker1, null);
        decorationState = editor.decorationsStateForScreenRowRange(0, 12);
        expect(
          decorationState[`${layer1Decoration2.id}-${marker1.id}`]
        ).toEqual({
          properties: { type: 'highlight', class: 'bar' },
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        });
      });
    });
  });

  describe('invisibles', () => {
    beforeEach(() => {
      editor.update({ showInvisibles: true });
    });

    it('substitutes invisible characters according to the given rules', () => {
      const previousLineText = editor.lineTextForScreenRow(0);
      editor.update({ invisibles: { eol: '?' } });
      expect(editor.lineTextForScreenRow(0)).not.toBe(previousLineText);
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(true);
      expect(editor.getInvisibles()).toEqual({ eol: '?' });
    });

    it('does not use invisibles if showInvisibles is set to false', () => {
      editor.update({ invisibles: { eol: '?' } });
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(true);

      editor.update({ showInvisibles: false });
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(false);
    });
  });

  describe('indent guides', () => {
    it('shows indent guides when `editor.showIndentGuide` is set to true and the editor is not mini', () => {
      editor.update({ showIndentGuide: false });
      expect(editor.tokensForScreenRow(1).slice(0, 3)).toEqual([
        {
          text: '  ',
          scopes: ['syntax--source syntax--js', 'leading-whitespace']
        },
        {
          text: 'var',
          scopes: ['syntax--source syntax--js', 'syntax--storage syntax--type']
        },
        { text: ' sort ', scopes: ['syntax--source syntax--js'] }
      ]);

      editor.update({ showIndentGuide: true });
      expect(editor.tokensForScreenRow(1).slice(0, 3)).toEqual([
        {
          text: '  ',
          scopes: [
            'syntax--source syntax--js',
            'leading-whitespace indent-guide'
          ]
        },
        {
          text: 'var',
          scopes: ['syntax--source syntax--js', 'syntax--storage syntax--type']
        },
        { text: ' sort ', scopes: ['syntax--source syntax--js'] }
      ]);

      editor.setMini(true);
      expect(editor.tokensForScreenRow(1).slice(0, 3)).toEqual([
        {
          text: '  ',
          scopes: ['syntax--source syntax--js', 'leading-whitespace']
        },
        {
          text: 'var',
          scopes: ['syntax--source syntax--js', 'syntax--storage syntax--type']
        },
        { text: ' sort ', scopes: ['syntax--source syntax--js'] }
      ]);
    });
  });

  describe('softWrapAtPreferredLineLength', () => {
    it('soft wraps the editor at the preferred line length unless the editor is narrower or the editor is mini', () => {
      editor.update({
        editorWidthInChars: 30,
        softWrapped: true,
        softWrapAtPreferredLineLength: true,
        preferredLineLength: 20
      });

      expect(editor.lineTextForScreenRow(0)).toBe('var quicksort = ');

      editor.update({ editorWidthInChars: 10 });
      expect(editor.lineTextForScreenRow(0)).toBe('var ');

      editor.update({ mini: true });
      expect(editor.lineTextForScreenRow(0)).toBe(
        'var quicksort = function () {'
      );
    });
  });

  describe('softWrapHangingIndentLength', () => {
    it('controls how much extra indentation is applied to soft-wrapped lines', () => {
      editor.setText('123456789');
      editor.update({
        editorWidthInChars: 8,
        softWrapped: true,
        softWrapHangingIndentLength: 2
      });
      expect(editor.lineTextForScreenRow(1)).toEqual('  9');

      editor.update({ softWrapHangingIndentLength: 4 });
      expect(editor.lineTextForScreenRow(1)).toEqual('    9');
    });
  });

  describe('::getElement', () => {
    it('returns an element', () =>
      expect(editor.getElement() instanceof HTMLElement).toBe(true));
  });

  describe('setMaxScreenLineLength', () => {
    it('sets the maximum line length in the editor before soft wrapping is forced', () => {
      expect(editor.getSoftWrapColumn()).toBe(500);
      editor.update({
        maxScreenLineLength: 1500
      });
      expect(editor.getSoftWrapColumn()).toBe(1500);
    });
  });
});

describe('TextEditor', () => {
  let editor;

  afterEach(() => {
    editor.destroy();
  });

  describe('.scopeDescriptorForBufferPosition(position)', () => {
    it('returns a default scope descriptor when no language mode is assigned', () => {
      editor = new TextEditor({ buffer: new TextBuffer() });
      const scopeDescriptor = editor.scopeDescriptorForBufferPosition([0, 0]);
      expect(scopeDescriptor.getScopesArray()).toEqual(['text']);
    });
  });

  describe('.syntaxTreeScopeDescriptorForBufferPosition(position)', () => {
    it('returns the result of scopeDescriptorForBufferPosition() when textmate language mode is used', async () => {
      atom.config.set('core.useTreeSitterParsers', false);
      editor = await atom.workspace.open('sample.js', { autoIndent: false });
      await atom.packages.activatePackage('language-javascript');

      let buffer = editor.getBuffer();

      let languageMode = new TextMateLanguageMode({
        buffer,
        grammar: atom.grammars.grammarForScopeName('source.js')
      });

      buffer.setLanguageMode(languageMode);

      languageMode.startTokenizing();
      while (languageMode.firstInvalidRow() != null) {
        advanceClock();
      }

      const syntaxTreeeScopeDescriptor = editor.syntaxTreeScopeDescriptorForBufferPosition(
        [4, 17]
      );
      expect(syntaxTreeeScopeDescriptor.getScopesArray()).toEqual([
        'source.js',
        'support.variable.property.js'
      ]);
    });

    it('returns the result of syntaxTreeScopeDescriptorForBufferPosition() when tree-sitter language mode is used', async () => {
      editor = await atom.workspace.open('sample.js', { autoIndent: false });
      await atom.packages.activatePackage('language-javascript');

      let buffer = editor.getBuffer();

      buffer.setLanguageMode(
        new TreeSitterLanguageMode({
          buffer,
          grammar: atom.grammars.grammarForScopeName('source.js')
        })
      );

      const syntaxTreeeScopeDescriptor = editor.syntaxTreeScopeDescriptorForBufferPosition(
        [4, 17]
      );
      expect(syntaxTreeeScopeDescriptor.getScopesArray()).toEqual([
        'source.js',
        'program',
        'variable_declaration',
        'variable_declarator',
        'function',
        'statement_block',
        'variable_declaration',
        'variable_declarator',
        'function',
        'statement_block',
        'while_statement',
        'parenthesized_expression',
        'binary_expression',
        'member_expression',
        'property_identifier'
      ]);
    });
  });

  describe('.shouldPromptToSave()', () => {
    beforeEach(async () => {
      editor = await atom.workspace.open('sample.js');
      jasmine.unspy(editor, 'shouldPromptToSave');
      spyOn(atom.stateStore, 'isConnected').andReturn(true);
    });

    it('returns true when buffer has unsaved changes', () => {
      expect(editor.shouldPromptToSave()).toBeFalsy();
      editor.setText('changed');
      expect(editor.shouldPromptToSave()).toBeTruthy();
    });

    it("returns false when an editor's buffer is in use by more than one buffer", async () => {
      editor.setText('changed');

      atom.workspace.getActivePane().splitRight();
      const editor2 = await atom.workspace.open('sample.js', {
        autoIndent: false
      });
      expect(editor.shouldPromptToSave()).toBeFalsy();

      editor2.destroy();
      expect(editor.shouldPromptToSave()).toBeTruthy();
    });

    it('returns true when the window is closing if the file has changed on disk', async () => {
      jasmine.useRealClock();

      editor.setText('initial stuff');
      await editor.saveAs(temp.openSync('test-file').path);

      editor.setText('other stuff');
      fs.writeFileSync(editor.getPath(), 'new stuff');
      expect(
        editor.shouldPromptToSave({
          windowCloseRequested: true,
          projectHasPaths: true
        })
      ).toBeFalsy();

      await new Promise(resolve => editor.onDidConflict(resolve));
      expect(
        editor.shouldPromptToSave({
          windowCloseRequested: true,
          projectHasPaths: true
        })
      ).toBeTruthy();
    });

    it('returns false when the window is closing and the project has one or more directory paths', () => {
      editor.setText('changed');
      expect(
        editor.shouldPromptToSave({
          windowCloseRequested: true,
          projectHasPaths: true
        })
      ).toBeFalsy();
    });

    it('returns false when the window is closing and the project has no directory paths', () => {
      editor.setText('changed');
      expect(
        editor.shouldPromptToSave({
          windowCloseRequested: true,
          projectHasPaths: false
        })
      ).toBeTruthy();
    });
  });

  describe('.toggleLineCommentsInSelection()', () => {
    beforeEach(async () => {
      await atom.packages.activatePackage('language-javascript');
      editor = await atom.workspace.open('sample.js');
    });

    it('toggles comments on the selected lines', () => {
      editor.setSelectedBufferRange([[4, 5], [7, 5]]);
      editor.toggleLineCommentsInSelection();

      expect(editor.lineTextForBufferRow(4)).toBe(
        '    // while(items.length > 0) {'
      );
      expect(editor.lineTextForBufferRow(5)).toBe(
        '    //   current = items.shift();'
      );
      expect(editor.lineTextForBufferRow(6)).toBe(
        '    //   current < pivot ? left.push(current) : right.push(current);'
      );
      expect(editor.lineTextForBufferRow(7)).toBe('    // }');
      expect(editor.getSelectedBufferRange()).toEqual([[4, 8], [7, 8]]);

      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(4)).toBe(
        '    while(items.length > 0) {'
      );
      expect(editor.lineTextForBufferRow(5)).toBe(
        '      current = items.shift();'
      );
      expect(editor.lineTextForBufferRow(6)).toBe(
        '      current < pivot ? left.push(current) : right.push(current);'
      );
      expect(editor.lineTextForBufferRow(7)).toBe('    }');
    });

    it('does not comment the last line of a non-empty selection if it ends at column 0', () => {
      editor.setSelectedBufferRange([[4, 5], [7, 0]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(4)).toBe(
        '    // while(items.length > 0) {'
      );
      expect(editor.lineTextForBufferRow(5)).toBe(
        '    //   current = items.shift();'
      );
      expect(editor.lineTextForBufferRow(6)).toBe(
        '    //   current < pivot ? left.push(current) : right.push(current);'
      );
      expect(editor.lineTextForBufferRow(7)).toBe('    }');
    });

    it('uncomments lines if all lines match the comment regex', () => {
      editor.setSelectedBufferRange([[0, 0], [0, 1]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        '// var quicksort = function () {'
      );

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        '// // var quicksort = function () {'
      );
      expect(editor.lineTextForBufferRow(1)).toBe(
        '//   var sort = function(items) {'
      );
      expect(editor.lineTextForBufferRow(2)).toBe(
        '//     if (items.length <= 1) return items;'
      );

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        '// var quicksort = function () {'
      );
      expect(editor.lineTextForBufferRow(1)).toBe(
        '  var sort = function(items) {'
      );
      expect(editor.lineTextForBufferRow(2)).toBe(
        '    if (items.length <= 1) return items;'
      );

      editor.setSelectedBufferRange([[0, 0], [0, Infinity]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        'var quicksort = function () {'
      );
    });

    it('uncomments commented lines separated by an empty line', () => {
      editor.setSelectedBufferRange([[0, 0], [1, Infinity]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        '// var quicksort = function () {'
      );
      expect(editor.lineTextForBufferRow(1)).toBe(
        '//   var sort = function(items) {'
      );

      editor.getBuffer().insert([0, Infinity], '\n');

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe(
        'var quicksort = function () {'
      );
      expect(editor.lineTextForBufferRow(1)).toBe('');
      expect(editor.lineTextForBufferRow(2)).toBe(
        '  var sort = function(items) {'
      );
    });

    it('preserves selection emptiness', () => {
      editor.setCursorBufferPosition([4, 0]);
      editor.toggleLineCommentsInSelection();
      expect(editor.getLastSelection().isEmpty()).toBeTruthy();
    });

    it('does not explode if the current language mode has no comment regex', () => {
      const editor = new TextEditor({
        buffer: new TextBuffer({ text: 'hello' })
      });
      editor.setSelectedBufferRange([[0, 0], [0, 5]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(0)).toBe('hello');
    });

    it('does nothing for empty lines and null grammar', () => {
      atom.grammars.assignLanguageMode(editor, null);
      editor.setCursorBufferPosition([10, 0]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(10)).toBe('');
    });

    it('uncomments when the line lacks the trailing whitespace in the comment regex', () => {
      editor.setCursorBufferPosition([10, 0]);
      editor.toggleLineCommentsInSelection();

      expect(editor.lineTextForBufferRow(10)).toBe('// ');
      expect(editor.getSelectedBufferRange()).toEqual([[10, 3], [10, 3]]);
      editor.backspace();
      expect(editor.lineTextForBufferRow(10)).toBe('//');

      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(10)).toBe('');
      expect(editor.getSelectedBufferRange()).toEqual([[10, 0], [10, 0]]);
    });

    it('uncomments when the line has leading whitespace', () => {
      editor.setCursorBufferPosition([10, 0]);
      editor.toggleLineCommentsInSelection();

      expect(editor.lineTextForBufferRow(10)).toBe('// ');
      editor.moveToBeginningOfLine();
      editor.insertText('  ');
      editor.setSelectedBufferRange([[10, 0], [10, 0]]);
      editor.toggleLineCommentsInSelection();
      expect(editor.lineTextForBufferRow(10)).toBe('  ');
    });
  });

  describe('.toggleLineCommentsForBufferRows', () => {
    describe('xml', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-xml');
        editor = await atom.workspace.open('test.xml');
        editor.setText('<!-- test -->');
      });

      it('removes the leading whitespace from the comment end pattern match when uncommenting lines', () => {
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe('test');
      });

      it('does not select the new delimiters', () => {
        editor.setText('<!-- test -->');
        let delimLength = '<!--'.length;
        let selection = editor.addSelectionForBufferRange([
          [0, delimLength],
          [0, delimLength]
        ]);

        {
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.isEmpty()).toBe(true);
          expect(range.start.column).toBe(0);
        }

        {
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.isEmpty()).toBe(true);
          expect(range.start.column).toBe(delimLength + 1);
        }

        {
          selection.setBufferRange([
            [0, delimLength],
            [0, delimLength + 1 + 'test'.length]
          ]);
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.start.column).toBe(0);
          expect(range.end.column).toBe('test'.length);
        }

        {
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.start.column).toBe(delimLength + 1);
          expect(range.end.column).toBe(delimLength + 1 + 'test'.length);
        }

        {
          editor.setText('    test');
          selection.setBufferRange([[0, 4], [0, 4]]);
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.isEmpty()).toBe(true);
          expect(range.start.column).toBe(4 + delimLength + 1);
        }

        {
          editor.setText('    test');
          selection.setBufferRange([[0, 8], [0, 8]]);
          selection.selectToBeginningOfWord();
          selection.toggleLineComments();

          const range = selection.getBufferRange();
          expect(range.start.column).toBe(4 + delimLength + 1);
          expect(range.end.column).toBe(4 + delimLength + 1 + 4);
        }
      });
    });

    describe('less', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-less');
        await atom.packages.activatePackage('language-css');
        editor = await atom.workspace.open('sample.less');
      });

      it('only uses the `commentEnd` pattern if it comes from the same grammar as the `commentStart` when commenting lines', () => {
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe('// @color: #4D926F;');
      });
    });

    describe('css', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-css');
        editor = await atom.workspace.open('css.css');
      });

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(0, 1);
        expect(editor.lineTextForBufferRow(0)).toBe('/* body {');
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px; */');
        expect(editor.lineTextForBufferRow(2)).toBe('  width: 110%;');
        expect(editor.lineTextForBufferRow(3)).toBe(
          '  font-weight: bold !important;'
        );

        editor.toggleLineCommentsForBufferRows(2, 2);
        expect(editor.lineTextForBufferRow(0)).toBe('/* body {');
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px; */');
        expect(editor.lineTextForBufferRow(2)).toBe('  /* width: 110%; */');
        expect(editor.lineTextForBufferRow(3)).toBe(
          '  font-weight: bold !important;'
        );

        editor.toggleLineCommentsForBufferRows(0, 1);
        expect(editor.lineTextForBufferRow(0)).toBe('body {');
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px;');
        expect(editor.lineTextForBufferRow(2)).toBe('  /* width: 110%; */');
        expect(editor.lineTextForBufferRow(3)).toBe(
          '  font-weight: bold !important;'
        );
      });

      it('uncomments lines with leading whitespace', () => {
        editor.setTextInBufferRange(
          [[2, 0], [2, Infinity]],
          '  /* width: 110%; */'
        );
        editor.toggleLineCommentsForBufferRows(2, 2);
        expect(editor.lineTextForBufferRow(2)).toBe('  width: 110%;');
      });

      it('uncomments lines with trailing whitespace', () => {
        editor.setTextInBufferRange(
          [[2, 0], [2, Infinity]],
          '/* width: 110%; */  '
        );
        editor.toggleLineCommentsForBufferRows(2, 2);
        expect(editor.lineTextForBufferRow(2)).toBe('width: 110%;  ');
      });

      it('uncomments lines with leading and trailing whitespace', () => {
        editor.setTextInBufferRange(
          [[2, 0], [2, Infinity]],
          '   /* width: 110%; */ '
        );
        editor.toggleLineCommentsForBufferRows(2, 2);
        expect(editor.lineTextForBufferRow(2)).toBe('   width: 110%; ');
      });
    });

    describe('coffeescript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-coffee-script');
        editor = await atom.workspace.open('coffee.coffee');
      });

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(4, 6);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    # pivot = items.shift()'
        );
        expect(editor.lineTextForBufferRow(5)).toBe('    # left = []');
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []');

        editor.toggleLineCommentsForBufferRows(4, 5);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    pivot = items.shift()'
        );
        expect(editor.lineTextForBufferRow(5)).toBe('    left = []');
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []');
      });

      it('comments/uncomments empty lines', () => {
        editor.toggleLineCommentsForBufferRows(4, 7);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    # pivot = items.shift()'
        );
        expect(editor.lineTextForBufferRow(5)).toBe('    # left = []');
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []');
        expect(editor.lineTextForBufferRow(7)).toBe('    # ');

        editor.toggleLineCommentsForBufferRows(4, 5);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    pivot = items.shift()'
        );
        expect(editor.lineTextForBufferRow(5)).toBe('    left = []');
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []');
        expect(editor.lineTextForBufferRow(7)).toBe('    # ');
      });
    });

    describe('javascript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-javascript');
        editor = await atom.workspace.open('sample.js');
      });

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(4, 7);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    // while(items.length > 0) {'
        );
        expect(editor.lineTextForBufferRow(5)).toBe(
          '    //   current = items.shift();'
        );
        expect(editor.lineTextForBufferRow(6)).toBe(
          '    //   current < pivot ? left.push(current) : right.push(current);'
        );
        expect(editor.lineTextForBufferRow(7)).toBe('    // }');

        editor.toggleLineCommentsForBufferRows(4, 5);
        expect(editor.lineTextForBufferRow(4)).toBe(
          '    while(items.length > 0) {'
        );
        expect(editor.lineTextForBufferRow(5)).toBe(
          '      current = items.shift();'
        );
        expect(editor.lineTextForBufferRow(6)).toBe(
          '    //   current < pivot ? left.push(current) : right.push(current);'
        );
        expect(editor.lineTextForBufferRow(7)).toBe('    // }');

        editor.setText('\tvar i;');
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe('\t// var i;');

        editor.setText('var i;');
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe('// var i;');

        editor.setText(' var i;');
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe(' // var i;');

        editor.setText('  ');
        editor.toggleLineCommentsForBufferRows(0, 0);
        expect(editor.lineTextForBufferRow(0)).toBe('  // ');

        editor.setText('    a\n  \n    b');
        editor.toggleLineCommentsForBufferRows(0, 2);
        expect(editor.lineTextForBufferRow(0)).toBe('    // a');
        expect(editor.lineTextForBufferRow(1)).toBe('    // ');
        expect(editor.lineTextForBufferRow(2)).toBe('    // b');

        editor.setText('    \n    // var i;');
        editor.toggleLineCommentsForBufferRows(0, 1);
        expect(editor.lineTextForBufferRow(0)).toBe('    ');
        expect(editor.lineTextForBufferRow(1)).toBe('    var i;');
      });
    });
  });

  describe('folding', () => {
    beforeEach(async () => {
      await atom.packages.activatePackage('language-javascript');
    });

    it('maintains cursor buffer position when a folding/unfolding', async () => {
      editor = await atom.workspace.open('sample.js', { autoIndent: false });
      editor.setCursorBufferPosition([5, 5]);
      editor.foldAll();
      expect(editor.getCursorBufferPosition()).toEqual([5, 5]);
    });

    describe('.unfoldAll()', () => {
      it('unfolds every folded line', async () => {
        editor = await atom.workspace.open('sample.js', { autoIndent: false });

        const initialScreenLineCount = editor.getScreenLineCount();
        editor.foldBufferRow(0);
        editor.foldBufferRow(1);
        expect(editor.getScreenLineCount()).toBeLessThan(
          initialScreenLineCount
        );
        editor.unfoldAll();
        expect(editor.getScreenLineCount()).toBe(initialScreenLineCount);
      });

      it('unfolds every folded line with comments', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {
          autoIndent: false
        });

        const initialScreenLineCount = editor.getScreenLineCount();
        editor.foldBufferRow(0);
        editor.foldBufferRow(5);
        expect(editor.getScreenLineCount()).toBeLessThan(
          initialScreenLineCount
        );
        editor.unfoldAll();
        expect(editor.getScreenLineCount()).toBe(initialScreenLineCount);
      });
    });

    describe('.foldAll()', () => {
      it('folds every foldable line', async () => {
        editor = await atom.workspace.open('sample.js', { autoIndent: false });

        editor.foldAll();
        const [fold1, fold2, fold3] = editor.unfoldAll();
        expect([fold1.start.row, fold1.end.row]).toEqual([0, 12]);
        expect([fold2.start.row, fold2.end.row]).toEqual([1, 9]);
        expect([fold3.start.row, fold3.end.row]).toEqual([4, 7]);
      });
    });

    describe('.foldBufferRow(bufferRow)', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('sample.js');
      });

      describe('when bufferRow can be folded', () => {
        it('creates a fold based on the syntactic region starting at the given row', () => {
          editor.foldBufferRow(1);
          const [fold] = editor.unfoldAll();
          expect([fold.start.row, fold.end.row]).toEqual([1, 9]);
        });
      });

      describe("when bufferRow can't be folded", () => {
        it('searches upward for the first row that begins a syntactic region containing the given buffer row (and folds it)', () => {
          editor.foldBufferRow(8);
          const [fold] = editor.unfoldAll();
          expect([fold.start.row, fold.end.row]).toEqual([1, 9]);
        });
      });

      describe('when the bufferRow is already folded', () => {
        it('searches upward for the first row that begins a syntactic region containing the folded row (and folds it)', () => {
          editor.foldBufferRow(2);
          expect(editor.isFoldedAtBufferRow(0)).toBe(false);
          expect(editor.isFoldedAtBufferRow(1)).toBe(true);

          editor.foldBufferRow(1);
          expect(editor.isFoldedAtBufferRow(0)).toBe(true);
        });
      });

      describe('when the bufferRow is a single-line comment', () => {
        it('searches upward for the first row that begins a syntactic region containing the folded row (and folds it)', () => {
          editor.buffer.insert([1, 0], '  //this is a single line comment\n');
          editor.foldBufferRow(1);
          const [fold] = editor.unfoldAll();
          expect([fold.start.row, fold.end.row]).toEqual([0, 13]);
        });
      });
    });

    describe('.foldCurrentRow()', () => {
      it('creates a fold at the location of the last cursor', async () => {
        editor = await atom.workspace.open();
        editor.setText('\nif (x) {\n  y()\n}');
        editor.setCursorBufferPosition([1, 0]);
        expect(editor.getScreenLineCount()).toBe(4);
        editor.foldCurrentRow();
        expect(editor.getScreenLineCount()).toBe(3);
      });

      it('does nothing when the current row cannot be folded', async () => {
        editor = await atom.workspace.open();
        editor.setText('var x;\nx++\nx++');
        editor.setCursorBufferPosition([0, 0]);
        expect(editor.getScreenLineCount()).toBe(3);
        editor.foldCurrentRow();
        expect(editor.getScreenLineCount()).toBe(3);
      });
    });

    describe('.foldAllAtIndentLevel(indentLevel)', () => {
      it('folds blocks of text at the given indentation level', async () => {
        editor = await atom.workspace.open('sample.js', { autoIndent: false });

        editor.foldAllAtIndentLevel(0);
        expect(editor.lineTextForScreenRow(0)).toBe(
          `var quicksort = function () {${editor.displayLayer.foldCharacter}};`
        );
        expect(editor.getLastScreenRow()).toBe(0);

        editor.foldAllAtIndentLevel(1);
        expect(editor.lineTextForScreenRow(0)).toBe(
          'var quicksort = function () {'
        );
        expect(editor.lineTextForScreenRow(1)).toBe(
          `  var sort = function(items) {${editor.displayLayer.foldCharacter}};`
        );
        expect(editor.getLastScreenRow()).toBe(4);

        editor.foldAllAtIndentLevel(2);
        expect(editor.lineTextForScreenRow(0)).toBe(
          'var quicksort = function () {'
        );
        expect(editor.lineTextForScreenRow(1)).toBe(
          '  var sort = function(items) {'
        );
        expect(editor.lineTextForScreenRow(2)).toBe(
          '    if (items.length <= 1) return items;'
        );
        expect(editor.getLastScreenRow()).toBe(9);
      });

      it('does not fold anything but the indentLevel', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {
          autoIndent: false
        });

        editor.foldAllAtIndentLevel(0);
        const folds = editor.unfoldAll();
        expect(folds.length).toBe(1);
        expect([folds[0].start.row, folds[0].end.row]).toEqual([0, 30]);
      });
    });
  });
});

function convertToHardTabs(buffer) {
  buffer.setText(buffer.getText().replace(/[ ]{2}/g, '\t'));
}
