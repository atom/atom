/** @babel */

const path = require('path');
const SelectNext = require('../lib/select-next');
const dedent = require('dedent');

describe("SelectNext", () => {
  let workspaceElement, editorElement, editor;

  beforeEach(async () => {
    workspaceElement = atom.views.getView(atom.workspace);
    atom.project.setPaths([path.join(__dirname, 'fixtures')]);

    editor = await atom.workspace.open('sample.js');
    editorElement = atom.views.getView(editor);

    jasmine.attachToDOM(workspaceElement);
    const activationPromise = atom.packages.activatePackage("find-and-replace");
    atom.commands.dispatch(editorElement, 'find-and-replace:show');
    await activationPromise;
  });

  describe("find-and-replace:select-next", () => {
    describe("when nothing is selected", () => {
      it("selects the word under the cursor", () => {
        editor.setCursorBufferPosition([1, 3]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([[[1, 2], [1, 5]]]);
      });
    });

    describe("when a word is selected", () => {
      describe("when the selection was created using select-next", () => {
        beforeEach(() => {});

        it("selects the next occurrence of the selected word skipping any non-word matches", () => {
          editor.setText(dedent`
            for
            information
            format
            another for
            fork
            a 3rd for is here
          `);

          editor.setCursorBufferPosition([0, 0]);
          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[3, 8], [3, 11]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[3, 8], [3, 11]],
            [[5, 6], [5, 9]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[3, 8], [3, 11]],
            [[5, 6], [5, 9]]
          ]);

          editor.setText("Testing reallyTesting");
          editor.setCursorBufferPosition([0, 0]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 7]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 7]]
          ]);});});

      describe("when the selection was not created using select-next", () => {
        it("selects the next occurrence of the selected characters including non-word matches", () => {
          editor.setText(dedent`
            for
            information
            format
            another for
            fork
            a 3rd for is here
          `);

          editor.setSelectedBufferRange([[0, 0], [0, 3]]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[1, 2], [1, 5]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[1, 2], [1, 5]],
            [[2, 0], [2, 3]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[1, 2], [1, 5]],
            [[2, 0], [2, 3]],
            [[3, 8], [3, 11]]
          ]);

          editor.setText("Testing reallyTesting");
          editor.setSelectedBufferRange([[0, 0], [0, 7]]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 7]],
            [[0, 14], [0, 21]]
          ]);
        });
      });
    });

    describe("when part of a word is selected", () => {
      it("selects the next occurrence of the selected text", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setSelectedBufferRange([[1, 2], [1, 5]]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 2], [1, 5]],
          [[2, 0], [2, 3]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 2], [1, 5]],
          [[2, 0], [2, 3]],
          [[3, 8], [3, 11]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 2], [1, 5]],
          [[2, 0], [2, 3]],
          [[3, 8], [3, 11]],
          [[4, 0], [4, 3]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 2], [1, 5]],
          [[2, 0], [2, 3]],
          [[3, 8], [3, 11]],
          [[4, 0], [4, 3]],
          [[5, 6], [5, 9]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 2], [1, 5]],
          [[2, 0], [2, 3]],
          [[3, 8], [3, 11]],
          [[4, 0], [4, 3]],
          [[5, 6], [5, 9]],
          [[0, 0], [0, 3]]
        ]);
      });
    });

    describe("when a non-word is selected", () => {
      it("selects the next occurrence of the selected text", () => {
        editor.setText(dedent`
          <!
          <a
        `);
        editor.setSelectedBufferRange([[0, 0], [0, 1]]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 1]],
          [[1, 0], [1, 1]]
        ]);
      })
    });

    describe("when the word is at a line boundary", () => {
      it("does not select the newlines", () => {
        editor.setText(dedent`
          a

          a
        `);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 1]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 1]],
          [[2, 0], [2, 1]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 1]],
          [[2, 0], [2, 1]]
        ]);
      });
    });

    it('honors the reversed orientation of previous selections', () => {
      editor.setText('ab ab ab ab')
      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: true})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      expect(editor.getSelections().length).toBe(2)
      expect(editor.getSelections().every(s => s.isReversed())).toBe(true)

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      expect(editor.getSelections().length).toBe(3)
      expect(editor.getSelections().every(s => s.isReversed())).toBe(true)

      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: false})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      expect(editor.getSelections().length).toBe(2)
      expect(editor.getSelections().every(s => !s.isReversed())).toBe(true)

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      expect(editor.getSelections().length).toBe(3)
      expect(editor.getSelections().every(s => !s.isReversed())).toBe(true)
    })
  });

  describe("find-and-replace:select-all", () => {
    describe("when there is no selection", () => {
      it("find and selects all occurrences of the word under the cursor", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]],
          [[3, 8], [3, 11]],
          [[5, 6], [5, 9]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]],
          [[3, 8], [3, 11]],
          [[5, 6], [5, 9]]
        ]);
      })
    });

    describe("when a word is selected", () => {
      describe("when the word was selected using select-next", () => {
        it("find and selects all occurrences of the word", () => {
          editor.setText(dedent`
            for
            information
            format
            another for
            fork
            a 3rd for is here
          `);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[3, 8], [3, 11]],
            [[5, 6], [5, 9]]
          ]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[0, 0], [0, 3]],
            [[3, 8], [3, 11]],
            [[5, 6], [5, 9]]
          ]);
        });
      });

      describe("when the word was not selected using select-next", () => {
        it("find and selects all occurrences including non-words", () => {
          editor.setText(dedent`
            for
            information
            format
            another for
            fork
            a 3rd for is here
          `);

          editor.setSelectedBufferRange([[3, 8], [3, 11]]);

          atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
          expect(editor.getSelectedBufferRanges()).toEqual([
            [[3, 8], [3, 11]],
            [[0, 0], [0, 3]],
            [[1, 2], [1, 5]],
            [[2, 0], [2, 3]],
            [[4, 0], [4, 3]],
            [[5, 6], [5, 9]]
          ]);
        });
      });
    });

    describe("when a non-word is selected", () => {
      it("selects the next occurrence of the selected text", () => {
        editor.setText(dedent`
          <!
          <a\
        `);
        editor.setSelectedBufferRange([[0, 0], [0, 1]]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-all');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 1]],
          [[1, 0], [1, 1]]
        ]);
      });
    });

    it('honors the reversed orientation of previous selections', () => {
      editor.setText('ab ab ab ab')
      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: true})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-all')
      expect(editor.getSelections().length).toBe(4)
      expect(editor.getSelections().every(s => s.isReversed())).toBe(true)

      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: false})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-all')
      expect(editor.getSelections().length).toBe(4)
      expect(editor.getSelections().every(s => !s.isReversed())).toBe(true)
    })
  });

  describe("find-and-replace:select-undo", () => {
    describe("when there is no selection", () => {
      it("does nothing", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]]
        ]);
      })
    });

    describe("when a word is selected", () => {
      it("unselects current word", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setSelectedBufferRange([[3, 8], [3, 11]]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 11], [3, 11]]
        ]);
      })
    });

    describe("when two words are selected", () => {
      it("unselects words in order", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setSelectedBufferRange([[3, 8], [3, 11]]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 8], [3, 11]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 11], [3, 11]]
        ]);
      })
    });

    describe("when three words are selected", () => {
      it("unselects words in order", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([0, 0]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');

        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]],
          [[3, 8], [3, 11]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]]
        ]);
      })
    });

    describe("when starting at the bottom word", () => {
      it("unselects words in order", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([5, 7]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]]
        ]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]],
          [[0, 0], [0, 3]]
        ]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]]
        ]);});

      it("doesn't stack previously selected", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([5, 7]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]]
        ]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-undo');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]],
          [[0, 0], [0, 3]]
        ]);
      });
    });
  });

  describe("find-and-replace:select-skip", () => {
    describe("when there is no selection", () => {
      it("does nothing", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-skip');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]]
        ]);
      })
    });

    describe("when a word is selected", () => {
      it("unselects current word and selects next match", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([3, 8]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 8], [3, 11]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-skip');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]]
        ]);
      })
    });

    describe("when two words are selected", () => {
      it("unselects second word and selects next match", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([0, 0]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-skip');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]],
          [[5, 6], [5, 9]]
        ]);

        atom.commands.dispatch(editorElement, 'find-and-replace:select-skip');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 3]]
        ]);
      });
    });

    describe("when starting at the bottom word", () => {
      it("unselects second word and selects next match", () => {
        editor.setText(dedent`
          for
          information
          format
          another for
          fork
          a 3rd for is here
        `);

        editor.setCursorBufferPosition([5, 7]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]]
        ]);
        atom.commands.dispatch(editorElement, 'find-and-replace:select-next');
        atom.commands.dispatch(editorElement, 'find-and-replace:select-skip');
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[5, 6], [5, 9]],
          [[3, 8], [3, 11]]
        ]);
      });
    });

    it('honors the reversed orientation of previous selections', () => {
      editor.setText('ab ab ab ab')
      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: true})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-skip')
      expect(editor.getSelections().length).toBe(1)
      expect(editor.getSelections().every(s => s.isReversed())).toBe(true)

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      atom.commands.dispatch(editorElement, 'find-and-replace:select-skip')
      expect(editor.getSelections().length).toBe(2)
      expect(editor.getSelections().every(s => s.isReversed())).toBe(true)

      editor.setSelectedBufferRange([[0, 0], [0, 2]], {reversed: false})

      atom.commands.dispatch(editorElement, 'find-and-replace:select-skip')
      expect(editor.getSelections().length).toBe(1)
      expect(editor.getSelections().every(s => !s.isReversed())).toBe(true)

      atom.commands.dispatch(editorElement, 'find-and-replace:select-next')
      atom.commands.dispatch(editorElement, 'find-and-replace:select-skip')
      expect(editor.getSelections().length).toBe(2)
      expect(editor.getSelections().every(s => !s.isReversed())).toBe(true)
    })
  });
});
