'use babel';

import SelectListView from 'atom-select-list';
import repositoryForPath from './helpers';

export default class DiffListView {
  constructor() {
    this.selectListView = new SelectListView({
      emptyMessage: 'No diffs in file',
      items: [],
      filterKeyForItem: diff => diff.lineText,
      elementForItem: diff => {
        const li = document.createElement('li');
        li.classList.add('two-lines');

        const primaryLine = document.createElement('div');
        primaryLine.classList.add('primary-line');
        primaryLine.textContent = diff.lineText;
        li.appendChild(primaryLine);

        const secondaryLine = document.createElement('div');
        secondaryLine.classList.add('secondary-line');
        secondaryLine.textContent = `-${diff.oldStart},${diff.oldLines} +${
          diff.newStart
        },${diff.newLines}`;
        li.appendChild(secondaryLine);

        return li;
      },
      didConfirmSelection: diff => {
        this.cancel();
        const bufferRow = diff.newStart > 0 ? diff.newStart - 1 : diff.newStart;
        this.editor.setCursorBufferPosition([bufferRow, 0], {
          autoscroll: true
        });
        this.editor.moveToFirstCharacterOfLine();
      },
      didCancelSelection: () => {
        this.cancel();
      }
    });
    this.selectListView.element.classList.add('diff-list-view');
    this.panel = atom.workspace.addModalPanel({
      item: this.selectListView,
      visible: false
    });
  }

  attach() {
    this.previouslyFocusedElement = document.activeElement;
    this.selectListView.reset();
    this.panel.show();
    this.selectListView.focus();
  }

  cancel() {
    this.panel.hide();
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus();
      this.previouslyFocusedElement = null;
    }
  }

  destroy() {
    this.cancel();
    this.panel.destroy();
    return this.selectListView.destroy();
  }

  async toggle() {
    const editor = atom.workspace.getActiveTextEditor();
    if (this.panel.isVisible()) {
      this.cancel();
    } else if (editor) {
      this.editor = editor;
      const repository = await repositoryForPath(this.editor.getPath());
      let diffs = repository
        ? repository.getLineDiffs(this.editor.getPath(), this.editor.getText())
        : [];
      if (!diffs) diffs = [];
      for (let diff of diffs) {
        const bufferRow = diff.newStart > 0 ? diff.newStart - 1 : diff.newStart;
        const lineText = this.editor.lineTextForBufferRow(bufferRow);
        diff.lineText = lineText ? lineText.trim() : '';
      }

      await this.selectListView.update({ items: diffs });
      this.attach();
    }
  }
}
