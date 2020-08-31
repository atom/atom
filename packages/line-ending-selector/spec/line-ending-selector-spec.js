const helpers = require('../lib/helpers');
const { TextEditor } = require('atom');

describe('line ending selector', () => {
  let lineEndingTile;

  beforeEach(() => {
    jasmine.useRealClock();

    waitsForPromise(() => {
      return atom.packages.activatePackage('status-bar');
    });

    waitsForPromise(() => {
      return atom.packages.activatePackage('line-ending-selector');
    });

    waits(1);

    runs(() => {
      const statusBar = atom.workspace.getFooterPanels()[0].getItem();
      lineEndingTile = statusBar.getRightTiles()[0].getItem();
      expect(lineEndingTile.element.className).toMatch(/line-ending-tile/);
      expect(lineEndingTile.element.textContent).toBe('');
    });
  });

  describe('Commands', () => {
    let editor, editorElement;

    beforeEach(() => {
      waitsForPromise(() => {
        return atom.workspace.open('mixed-endings.md').then(e => {
          editor = e;
          editorElement = atom.views.getView(editor);
          jasmine.attachToDOM(editorElement);
        });
      });
    });

    describe('When "line-ending-selector:convert-to-LF" is run', () => {
      it('converts the file to LF line endings', () => {
        editorElement.focus();
        atom.commands.dispatch(
          document.activeElement,
          'line-ending-selector:convert-to-LF'
        );
        expect(editor.getText()).toBe('Hello\nGoodbye\nMixed\n');
      });
    });

    describe('When "line-ending-selector:convert-to-LF" is run', () => {
      it('converts the file to CRLF line endings', () => {
        editorElement.focus();
        atom.commands.dispatch(
          document.activeElement,
          'line-ending-selector:convert-to-CRLF'
        );
        expect(editor.getText()).toBe('Hello\r\nGoodbye\r\nMixed\r\n');
      });
    });
  });

  describe('Status bar tile', () => {
    describe('when an empty file is opened', () => {
      it('uses the default line endings for the platform', () => {
        waitsFor(done => {
          spyOn(helpers, 'getProcessPlatform').andReturn('win32');

          atom.workspace.open('').then(editor => {
            const subscription = lineEndingTile.onDidChange(() => {
              subscription.dispose();
              expect(lineEndingTile.element.textContent).toBe('CRLF');
              expect(editor.getBuffer().getPreferredLineEnding()).toBe('\r\n');
              expect(getTooltipText(lineEndingTile.element)).toBe(
                'File uses CRLF (Windows) line endings'
              );

              done();
            });
          });
        });

        waitsFor(done => {
          helpers.getProcessPlatform.andReturn('darwin');

          atom.workspace.open('').then(editor => {
            const subscription = lineEndingTile.onDidChange(() => {
              subscription.dispose();
              expect(lineEndingTile.element.textContent).toBe('LF');
              expect(editor.getBuffer().getPreferredLineEnding()).toBe('\n');
              expect(getTooltipText(lineEndingTile.element)).toBe(
                'File uses LF (Unix) line endings'
              );

              done();
            });
          });
        });
      });

      describe('when the "defaultLineEnding" setting is set to "LF"', () => {
        beforeEach(() => {
          atom.config.set('line-ending-selector.defaultLineEnding', 'LF');
        });

        it('uses LF line endings, regardless of the platform', () => {
          waitsFor(done => {
            spyOn(helpers, 'getProcessPlatform').andReturn('win32');

            atom.workspace.open('').then(editor => {
              lineEndingTile.onDidChange(() => {
                expect(lineEndingTile.element.textContent).toBe('LF');
                expect(editor.getBuffer().getPreferredLineEnding()).toBe('\n');
                done();
              });
            });
          });
        });
      });

      describe('when the "defaultLineEnding" setting is set to "CRLF"', () => {
        beforeEach(() => {
          atom.config.set('line-ending-selector.defaultLineEnding', 'CRLF');
        });

        it('uses CRLF line endings, regardless of the platform', () => {
          waitsFor(done => {
            atom.workspace.open('').then(editor => {
              lineEndingTile.onDidChange(() => {
                expect(lineEndingTile.element.textContent).toBe('CRLF');
                expect(editor.getBuffer().getPreferredLineEnding()).toBe(
                  '\r\n'
                );
                done();
              });
            });
          });
        });
      });
    });

    describe('when a file is opened that contains only CRLF line endings', () => {
      it('displays "CRLF" as the line ending', () => {
        waitsFor(done => {
          atom.workspace.open('windows-endings.md').then(() => {
            lineEndingTile.onDidChange(() => {
              expect(lineEndingTile.element.textContent).toBe('CRLF');
              done();
            });
          });
        });
      });
    });

    describe('when a file is opened that contains only LF line endings', () => {
      it('displays "LF" as the line ending', () => {
        waitsFor(done => {
          atom.workspace.open('unix-endings.md').then(editor => {
            lineEndingTile.onDidChange(() => {
              expect(lineEndingTile.element.textContent).toBe('LF');
              expect(editor.getBuffer().getPreferredLineEnding()).toBe(null);
              done();
            });
          });
        });
      });
    });

    describe('when a file is opened that contains mixed line endings', () => {
      it('displays "Mixed" as the line ending', () => {
        waitsFor(done => {
          atom.workspace.open('mixed-endings.md').then(() => {
            lineEndingTile.onDidChange(() => {
              expect(lineEndingTile.element.textContent).toBe('Mixed');
              done();
            });
          });
        });
      });
    });

    describe('clicking the tile', () => {
      let lineEndingModal, lineEndingSelector;

      beforeEach(() => {
        jasmine.attachToDOM(atom.views.getView(atom.workspace));

        waitsFor(done =>
          atom.workspace
            .open('unix-endings.md')
            .then(() => lineEndingTile.onDidChange(done))
        );
      });

      describe('when the text editor has focus', () => {
        it('opens the line ending selector modal for the text editor', () => {
          atom.workspace.getCenter().activate();
          const item = atom.workspace.getActivePaneItem();
          expect(item.getFileName && item.getFileName()).toBe(
            'unix-endings.md'
          );

          lineEndingTile.element.dispatchEvent(new MouseEvent('click', {}));
          lineEndingModal = atom.workspace.getModalPanels()[0];
          lineEndingSelector = lineEndingModal.getItem();

          expect(lineEndingModal.isVisible()).toBe(true);
          expect(
            lineEndingSelector.element.contains(document.activeElement)
          ).toBe(true);
          let listItems = lineEndingSelector.element.querySelectorAll('li');
          expect(listItems[0].textContent).toBe('LF');
          expect(listItems[1].textContent).toBe('CRLF');
        });
      });

      describe('when the text editor does not have focus', () => {
        it('opens the line ending selector modal for the active text editor', () => {
          atom.workspace.getLeftDock().activate();
          const item = atom.workspace.getActivePaneItem();
          expect(item instanceof TextEditor).toBe(false);

          lineEndingTile.element.dispatchEvent(new MouseEvent('click', {}));
          lineEndingModal = atom.workspace.getModalPanels()[0];
          lineEndingSelector = lineEndingModal.getItem();

          expect(lineEndingModal.isVisible()).toBe(true);
          expect(
            lineEndingSelector.element.contains(document.activeElement)
          ).toBe(true);
          let listItems = lineEndingSelector.element.querySelectorAll('li');
          expect(listItems[0].textContent).toBe('LF');
          expect(listItems[1].textContent).toBe('CRLF');
        });
      });

      describe('when selecting a different line ending for the file', () => {
        it('changes the line endings in the buffer', () => {
          lineEndingTile.element.dispatchEvent(new MouseEvent('click', {}));
          lineEndingModal = atom.workspace.getModalPanels()[0];
          lineEndingSelector = lineEndingModal.getItem();

          const lineEndingChangedPromise = new Promise(resolve => {
            lineEndingTile.onDidChange(() => {
              expect(lineEndingTile.element.textContent).toBe('CRLF');
              const editor = atom.workspace.getActiveTextEditor();
              expect(editor.getText()).toBe('Hello\r\nGoodbye\r\nUnix\r\n');
              expect(editor.getBuffer().getPreferredLineEnding()).toBe('\r\n');
              resolve();
            });
          });

          lineEndingSelector.refs.queryEditor.setText('CR');
          lineEndingSelector.confirmSelection();
          expect(lineEndingModal.isVisible()).toBe(false);

          waitsForPromise(() => lineEndingChangedPromise);
        });
      });

      describe('when modal is exited', () => {
        it('leaves the tile selection as-is', () => {
          lineEndingTile.element.dispatchEvent(new MouseEvent('click', {}));
          lineEndingModal = atom.workspace.getModalPanels()[0];
          lineEndingSelector = lineEndingModal.getItem();

          lineEndingSelector.cancelSelection();
          expect(lineEndingTile.element.textContent).toBe('LF');
        });
      });
    });

    describe('closing the last text editor', () => {
      it('displays no line ending in the status bar', () => {
        waitsForPromise(() => {
          return atom.workspace.open('unix-endings.md').then(() => {
            atom.workspace.getActivePane().destroy();
            expect(lineEndingTile.element.textContent).toBe('');
          });
        });
      });
    });

    describe("when the buffer's line endings change", () => {
      let editor;

      beforeEach(() => {
        waitsFor(done => {
          atom.workspace.open('unix-endings.md').then(e => {
            editor = e;
            lineEndingTile.onDidChange(done);
          });
        });
      });

      it('updates the line ending text in the tile', () => {
        let tileText = lineEndingTile.element.textContent;
        let tileUpdateCount = 0;
        Object.defineProperty(lineEndingTile.element, 'textContent', {
          get() {
            return tileText;
          },

          set(text) {
            tileUpdateCount++;
            tileText = text;
          }
        });

        expect(lineEndingTile.element.textContent).toBe('LF');
        expect(getTooltipText(lineEndingTile.element)).toBe(
          'File uses LF (Unix) line endings'
        );

        waitsFor(done => {
          editor.setTextInBufferRange([[0, 0], [0, 0]], '... ');
          editor.setTextInBufferRange([[0, Infinity], [1, 0]], '\r\n', {
            normalizeLineEndings: false
          });
          lineEndingTile.onDidChange(done);
        });

        runs(() => {
          expect(tileUpdateCount).toBe(1);
          expect(lineEndingTile.element.textContent).toBe('Mixed');
          expect(getTooltipText(lineEndingTile.element)).toBe(
            'File uses mixed line endings'
          );
        });

        waitsFor(done => {
          atom.commands.dispatch(
            editor.getElement(),
            'line-ending-selector:convert-to-CRLF'
          );
          lineEndingTile.onDidChange(done);
        });

        runs(() => {
          expect(tileUpdateCount).toBe(2);
          expect(lineEndingTile.element.textContent).toBe('CRLF');
          expect(getTooltipText(lineEndingTile.element)).toBe(
            'File uses CRLF (Windows) line endings'
          );
        });

        waitsFor(done => {
          atom.commands.dispatch(
            editor.getElement(),
            'line-ending-selector:convert-to-LF'
          );
          lineEndingTile.onDidChange(done);
        });

        runs(() => {
          expect(tileUpdateCount).toBe(3);
          expect(lineEndingTile.element.textContent).toBe('LF');
        });

        runs(() => {
          editor.setTextInBufferRange([[0, 0], [0, 0]], '\n');
        });

        waits(100);

        runs(() => {
          expect(tileUpdateCount).toBe(3);
        });
      });
    });
  });
});

function getTooltipText(element) {
  const [tooltip] = atom.tooltips.findTooltips(element);
  return tooltip.getTitle();
}
