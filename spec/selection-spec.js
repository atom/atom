const TextEditor = require('../src/text-editor');

describe('Selection', () => {
  let buffer, editor, selection;

  beforeEach(() => {
    buffer = atom.project.bufferForPathSync('sample.js');
    editor = new TextEditor({ buffer, tabLength: 2 });
    selection = editor.getLastSelection();
  });

  afterEach(() => buffer.destroy());

  describe('.deleteSelectedText()', () => {
    describe('when nothing is selected', () => {
      it('deletes nothing', () => {
        selection.setBufferRange([[0, 3], [0, 3]]);
        selection.deleteSelectedText();
        expect(buffer.lineForRow(0)).toBe('var quicksort = function () {');
      });
    });

    describe('when one line is selected', () => {
      it('deletes selected text and clears the selection', () => {
        selection.setBufferRange([[0, 4], [0, 14]]);
        selection.deleteSelectedText();
        expect(buffer.lineForRow(0)).toBe('var = function () {');

        const endOfLine = buffer.lineForRow(0).length;
        selection.setBufferRange([[0, 0], [0, endOfLine]]);
        selection.deleteSelectedText();
        expect(buffer.lineForRow(0)).toBe('');

        expect(selection.isEmpty()).toBeTruthy();
      });
    });

    describe('when multiple lines are selected', () => {
      it('deletes selected text and clears the selection', () => {
        selection.setBufferRange([[0, 1], [2, 39]]);
        selection.deleteSelectedText();
        expect(buffer.lineForRow(0)).toBe('v;');
        expect(selection.isEmpty()).toBeTruthy();
      });
    });

    describe('when the cursor precedes the tail', () => {
      it('deletes selected text and clears the selection', () => {
        selection.cursor.setScreenPosition([0, 13]);
        selection.selectToScreenPosition([0, 4]);

        selection.delete();
        expect(buffer.lineForRow(0)).toBe('var  = function () {');
        expect(selection.isEmpty()).toBeTruthy();
      });
    });
  });

  describe('.isReversed()', () => {
    it('returns true if the cursor precedes the tail', () => {
      selection.cursor.setScreenPosition([0, 20]);
      selection.selectToScreenPosition([0, 10]);
      expect(selection.isReversed()).toBeTruthy();

      selection.selectToScreenPosition([0, 25]);
      expect(selection.isReversed()).toBeFalsy();
    });
  });

  describe('.selectLine(row)', () => {
    describe('when passed a row', () => {
      it('selects the specified row', () => {
        selection.setBufferRange([[2, 4], [3, 4]]);
        selection.selectLine(5);
        expect(selection.getBufferRange()).toEqual([[5, 0], [6, 0]]);
      });
    });

    describe('when not passed a row', () => {
      it('selects all rows spanned by the selection', () => {
        selection.setBufferRange([[2, 4], [3, 4]]);
        selection.selectLine();
        expect(selection.getBufferRange()).toEqual([[2, 0], [4, 0]]);
      });
    });
  });

  describe("when the selection's range is moved", () => {
    it('notifies ::onDidChangeRange observers', () => {
      selection.setBufferRange([[2, 0], [2, 10]]);
      const changeScreenRangeHandler = jasmine.createSpy(
        'changeScreenRangeHandler'
      );
      selection.onDidChangeRange(changeScreenRangeHandler);
      buffer.insert([2, 5], 'abc');
      expect(changeScreenRangeHandler).toHaveBeenCalled();
      expect(
        changeScreenRangeHandler.mostRecentCall.args[0]
      ).not.toBeUndefined();
    });
  });

  describe("when only the selection's tail is moved (regression)", () => {
    it('notifies ::onDidChangeRange observers', () => {
      selection.setBufferRange([[2, 0], [2, 10]], { reversed: true });
      const changeScreenRangeHandler = jasmine.createSpy(
        'changeScreenRangeHandler'
      );
      selection.onDidChangeRange(changeScreenRangeHandler);

      buffer.insert([2, 5], 'abc');
      expect(changeScreenRangeHandler).toHaveBeenCalled();
      expect(
        changeScreenRangeHandler.mostRecentCall.args[0]
      ).not.toBeUndefined();
    });
  });

  describe('when the selection is destroyed', () => {
    it('destroys its marker', () => {
      selection.setBufferRange([[2, 0], [2, 10]]);
      const { marker } = selection;
      selection.destroy();
      expect(marker.isDestroyed()).toBeTruthy();
    });
  });

  describe('.insertText(text, options)', () => {
    it('allows pasting white space only lines when autoIndent is enabled', () => {
      selection.setBufferRange([[0, 0], [0, 0]]);
      selection.insertText('    \n    \n\n', { autoIndent: true });
      expect(buffer.lineForRow(0)).toBe('    ');
      expect(buffer.lineForRow(1)).toBe('    ');
      expect(buffer.lineForRow(2)).toBe('');
    });

    it('auto-indents if only a newline is inserted', () => {
      selection.setBufferRange([[2, 0], [3, 0]]);
      selection.insertText('\n', { autoIndent: true });
      expect(buffer.lineForRow(2)).toBe('  ');
    });

    it('auto-indents if only a carriage return + newline is inserted', () => {
      selection.setBufferRange([[2, 0], [3, 0]]);
      selection.insertText('\r\n', { autoIndent: true });
      expect(buffer.lineForRow(2)).toBe('  ');
    });

    it('does not adjust the indent of trailing lines if preserveTrailingLineIndentation is true', () => {
      selection.setBufferRange([[5, 0], [5, 0]]);
      selection.insertText('      foo\n    bar\n', {
        preserveTrailingLineIndentation: true,
        indentBasis: 1
      });
      expect(buffer.lineForRow(6)).toBe('    bar');
    });
  });

  describe('.fold()', () => {
    it('folds the buffer range spanned by the selection', () => {
      selection.setBufferRange([[0, 3], [1, 6]]);
      selection.fold();

      expect(selection.getScreenRange()).toEqual([[0, 4], [0, 4]]);
      expect(selection.getBufferRange()).toEqual([[1, 6], [1, 6]]);
      expect(editor.lineTextForScreenRow(0)).toBe(
        `var${editor.displayLayer.foldCharacter}sort = function(items) {`
      );
      expect(editor.isFoldedAtBufferRow(0)).toBe(true);
    });

    it("doesn't create a fold when the selection is empty", () => {
      selection.setBufferRange([[0, 3], [0, 3]]);
      selection.fold();

      expect(selection.getScreenRange()).toEqual([[0, 3], [0, 3]]);
      expect(selection.getBufferRange()).toEqual([[0, 3], [0, 3]]);
      expect(editor.lineTextForScreenRow(0)).toBe(
        'var quicksort = function () {'
      );
      expect(editor.isFoldedAtBufferRow(0)).toBe(false);
    });
  });

  describe('within a read-only editor', () => {
    beforeEach(() => {
      editor.setReadOnly(true);
      selection.setBufferRange([[0, 0], [0, 13]]);
    });

    const modifications = [
      {
        name: 'insertText',
        op: opts => selection.insertText('yes', opts)
      },
      {
        name: 'backspace',
        op: opts => selection.backspace(opts)
      },
      {
        name: 'deleteToPreviousWordBoundary',
        op: opts => selection.deleteToPreviousWordBoundary(opts)
      },
      {
        name: 'deleteToNextWordBoundary',
        op: opts => selection.deleteToNextWordBoundary(opts)
      },
      {
        name: 'deleteToBeginningOfWord',
        op: opts => selection.deleteToBeginningOfWord(opts)
      },
      {
        name: 'deleteToBeginningOfLine',
        op: opts => selection.deleteToBeginningOfLine(opts)
      },
      {
        name: 'delete',
        op: opts => selection.delete(opts)
      },
      {
        name: 'deleteToEndOfLine',
        op: opts => selection.deleteToEndOfLine(opts)
      },
      {
        name: 'deleteToEndOfWord',
        op: opts => selection.deleteToEndOfWord(opts)
      },
      {
        name: 'deleteToBeginningOfSubword',
        op: opts => selection.deleteToBeginningOfSubword(opts)
      },
      {
        name: 'deleteToEndOfSubword',
        op: opts => selection.deleteToEndOfSubword(opts)
      },
      {
        name: 'deleteSelectedText',
        op: opts => selection.deleteSelectedText(opts)
      },
      {
        name: 'deleteLine',
        op: opts => selection.deleteLine(opts)
      },
      {
        name: 'joinLines',
        op: opts => selection.joinLines(opts)
      },
      {
        name: 'outdentSelectedRows',
        op: opts => selection.outdentSelectedRows(opts)
      },
      {
        name: 'autoIndentSelectedRows',
        op: opts => selection.autoIndentSelectedRows(opts)
      },
      {
        name: 'toggleLineComments',
        op: opts => selection.toggleLineComments(opts)
      },
      {
        name: 'cutToEndOfLine',
        op: opts => selection.cutToEndOfLine(false, opts)
      },
      {
        name: 'cutToEndOfBufferLine',
        op: opts => selection.cutToEndOfBufferLine(false, opts)
      },
      {
        name: 'cut',
        op: opts => selection.cut(false, false, opts.bypassReadOnly)
      },
      {
        name: 'indent',
        op: opts => selection.indent(opts)
      },
      {
        name: 'indentSelectedRows',
        op: opts => selection.indentSelectedRows(opts)
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
