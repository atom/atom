/** @babel */

const TextEditor = require('../src/text-editor');

describe('WorkspaceCenter', () => {
  describe('.observeTextEditors()', () => {
    it('invokes the observer with current and future text editors', () => {
      const workspaceCenter = atom.workspace.getCenter();
      const pane = workspaceCenter.getActivePane();
      const observed = [];

      const editorAddedBeforeRegisteringObserver = new TextEditor();
      const nonEditorItemAddedBeforeRegisteringObserver = document.createElement(
        'div'
      );
      pane.activateItem(editorAddedBeforeRegisteringObserver);
      pane.activateItem(nonEditorItemAddedBeforeRegisteringObserver);

      workspaceCenter.observeTextEditors(editor => observed.push(editor));

      const editorAddedAfterRegisteringObserver = new TextEditor();
      const nonEditorItemAddedAfterRegisteringObserver = document.createElement(
        'div'
      );
      pane.activateItem(editorAddedAfterRegisteringObserver);
      pane.activateItem(nonEditorItemAddedAfterRegisteringObserver);

      expect(observed).toEqual([
        editorAddedBeforeRegisteringObserver,
        editorAddedAfterRegisteringObserver
      ]);
    });
  });
});
