const { CompositeDisposable } = require('atom');
const { repositoryForPath } = require('./helpers');

const MAX_BUFFER_LENGTH_TO_DIFF = 2 * 1024 * 1024;

module.exports = class GitDiffView {
  constructor(editor) {
    this.updateDiffs = this.updateDiffs.bind(this);
    this.editor = editor;
    this.subscriptions = new CompositeDisposable();
    this.decorations = {};
    this.markers = [];
  }

  start() {
    const editorElement = this.editor.getElement();

    this.subscribeToRepository();

    this.subscriptions.add(
      this.editor.onDidStopChanging(this.updateDiffs),
      this.editor.onDidChangePath(this.updateDiffs),
      atom.project.onDidChangePaths(() => this.subscribeToRepository()),
      atom.commands.add(editorElement, 'git-diff:move-to-next-diff', () =>
        this.moveToNextDiff()
      ),
      atom.commands.add(editorElement, 'git-diff:move-to-previous-diff', () =>
        this.moveToPreviousDiff()
      ),
      atom.config.onDidChange('git-diff.showIconsInEditorGutter', () =>
        this.updateIconDecoration()
      ),
      atom.config.onDidChange('editor.showLineNumbers', () =>
        this.updateIconDecoration()
      ),
      editorElement.onDidAttach(() => this.updateIconDecoration()),
      this.editor.onDidDestroy(() => {
        this.cancelUpdate();
        this.removeDecorations();
        this.subscriptions.dispose();
      })
    );

    this.updateIconDecoration();
    this.scheduleUpdate();
  }

  moveToNextDiff() {
    const cursorLineNumber = this.editor.getCursorBufferPosition().row + 1;
    let nextDiffLineNumber = null;
    let firstDiffLineNumber = null;
    if (this.diffs) {
      for (const { newStart } of this.diffs) {
        if (newStart > cursorLineNumber) {
          if (nextDiffLineNumber == null) nextDiffLineNumber = newStart - 1;
          nextDiffLineNumber = Math.min(newStart - 1, nextDiffLineNumber);
        }

        if (firstDiffLineNumber == null) firstDiffLineNumber = newStart - 1;
        firstDiffLineNumber = Math.min(newStart - 1, firstDiffLineNumber);
      }
    }

    // Wrap around to the first diff in the file
    if (
      atom.config.get('git-diff.wrapAroundOnMoveToDiff') &&
      nextDiffLineNumber == null
    ) {
      nextDiffLineNumber = firstDiffLineNumber;
    }

    this.moveToLineNumber(nextDiffLineNumber);
  }

  updateIconDecoration() {
    const gutter = this.editor.getElement().querySelector('.gutter');
    if (gutter) {
      if (
        atom.config.get('editor.showLineNumbers') &&
        atom.config.get('git-diff.showIconsInEditorGutter')
      ) {
        gutter.classList.add('git-diff-icon');
      } else {
        gutter.classList.remove('git-diff-icon');
      }
    }
  }

  moveToPreviousDiff() {
    const cursorLineNumber = this.editor.getCursorBufferPosition().row + 1;
    let previousDiffLineNumber = -1;
    let lastDiffLineNumber = -1;
    if (this.diffs) {
      for (const { newStart } of this.diffs) {
        if (newStart < cursorLineNumber) {
          previousDiffLineNumber = Math.max(
            newStart - 1,
            previousDiffLineNumber
          );
        }
        lastDiffLineNumber = Math.max(newStart - 1, lastDiffLineNumber);
      }
    }

    // Wrap around to the last diff in the file
    if (
      atom.config.get('git-diff.wrapAroundOnMoveToDiff') &&
      previousDiffLineNumber === -1
    ) {
      previousDiffLineNumber = lastDiffLineNumber;
    }

    this.moveToLineNumber(previousDiffLineNumber);
  }

  moveToLineNumber(lineNumber) {
    if (lineNumber != null && lineNumber >= 0) {
      this.editor.setCursorBufferPosition([lineNumber, 0]);
      this.editor.moveToFirstCharacterOfLine();
    }
  }

  subscribeToRepository() {
    this.repository = repositoryForPath(this.editor.getPath());
    if (this.repository) {
      this.subscriptions.add(
        this.repository.onDidChangeStatuses(() => {
          this.scheduleUpdate();
        })
      );
      this.subscriptions.add(
        this.repository.onDidChangeStatus(changedPath => {
          if (changedPath === this.editor.getPath()) this.scheduleUpdate();
        })
      );
    }
  }

  cancelUpdate() {
    clearImmediate(this.immediateId);
  }

  scheduleUpdate() {
    this.cancelUpdate();
    this.immediateId = setImmediate(this.updateDiffs);
  }

  updateDiffs() {
    if (this.editor.isDestroyed()) return;
    this.removeDecorations();
    const path = this.editor && this.editor.getPath();
    if (
      path &&
      this.editor.getBuffer().getLength() < MAX_BUFFER_LENGTH_TO_DIFF
    ) {
      this.diffs =
        this.repository &&
        this.repository.getLineDiffs(path, this.editor.getText());
      if (this.diffs) this.addDecorations(this.diffs);
    }
  }

  addDecorations(diffs) {
    for (const { newStart, oldLines, newLines } of diffs) {
      const startRow = newStart - 1;
      const endRow = newStart + newLines - 1;
      if (oldLines === 0 && newLines > 0) {
        this.markRange(startRow, endRow, 'git-line-added');
      } else if (newLines === 0 && oldLines > 0) {
        if (startRow < 0) {
          this.markRange(0, 0, 'git-previous-line-removed');
        } else {
          this.markRange(startRow, startRow, 'git-line-removed');
        }
      } else {
        this.markRange(startRow, endRow, 'git-line-modified');
      }
    }
  }

  removeDecorations() {
    for (let marker of this.markers) marker.destroy();
    this.markers = [];
  }

  markRange(startRow, endRow, klass) {
    const marker = this.editor.markBufferRange([[startRow, 0], [endRow, 0]], {
      invalidate: 'never'
    });
    this.editor.decorateMarker(marker, { type: 'line-number', class: klass });
    this.markers.push(marker);
  }
};
