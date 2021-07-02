'use babel';

import { CompositeDisposable } from 'atom';
import repositoryForPath from './helpers';

const MAX_BUFFER_LENGTH_TO_DIFF = 2 * 1024 * 1024;

/**
 * @describe Handles per-editor event and repository subscriptions.
 * @param editor {Atom.TextEditor} - The editor this view will manage.
 */
export default class GitDiffView {
  constructor(editor, editorElement) {
    // These are the only members guaranteed to exist.
    this.subscriptions = new CompositeDisposable();
    this.editor = editor;
    this.editorElement = editorElement;
    this.repository = null;
    this.markers = new Map();

    // Assign `null` to all possible child vars here so the JS engine doesn't
    // have to re-evaluate the microcode when we do eventually need them.
    this.releaseChildren();

    // I know this looks janky but it works. Class methods are available
    // before the constructor is executed. It's a micro-opt above lambdas.
    const subscribeToRepository = this.subscribeToRepository.bind(this);
    // WARNING: This gets handed to requestAnimationFrame, so it must be bound.
    this.updateDiffs = this.updateDiffs.bind(this);

    subscribeToRepository();

    this.subscriptions.add(
      atom.project.onDidChangePaths(subscribeToRepository)
    );
  }

  /**
   * @describe Handles tear down of destructables and subscriptions.
   *   Does not handle release of memory. This method should only be called
   *   just before this object is freed, and should only tear down the main
   *   object components that are guarunteed to exist at all times.
   */
  destroy() {
    this.subscriptions.dispose();
    this.destroyChildren();
    this.markers.clear();
  }

  /**
   * @describe Destroys this objects children (non-freeing), it's intended
   *   to be an ease-of use function for maintaing this object. This method
   *   should only tear down objects that are selectively allocated upon
   *   repository discovery.
   *
   *   Example: this.diffs only exists when we have a repository.
   */
  destroyChildren() {
    if (this._animationId) cancelAnimationFrame(this._animationId);

    if (this.diffs)
      for (const diff of this.diffs) this.markers.get(diff).destroy();
  }

  /**
   * @describe The memory releasing complement function of `destroyChildren`.
   *   frees the memory allocated at all child object storage locations
   *   when there is no repository.
   */
  releaseChildren() {
    this.diffs = null;
    this._repoSubs = null;
    this._animationId = null;
    this.editorPath = null;
    this.buffer = null;
  }

  /**
   * @describe handles all subscriptions based on the repository in focus
   */
  async subscribeToRepository() {
    if (this._repoSubs !== null) {
      this._repoSubs.dispose();
      this.subscriptions.remove(this._repoSubs);
    }

    // Don't cache the path unless we know we need it.
    let editorPath = this.editor.getPath();

    this.repository = await repositoryForPath(editorPath);
    if (this.repository !== null) {
      this.editorPath = editorPath;
      this.buffer = this.editor.getBuffer();

      const subscribeToRepository = this.subscribeToRepository.bind(this);
      const updateIconDecoration = this.updateIconDecoration.bind(this);
      const scheduleUpdate = this.scheduleUpdate.bind(this);

      this._repoSubs = new CompositeDisposable(
        this.repository.onDidDestroy(subscribeToRepository),
        this.repository.onDidChangeStatuses(scheduleUpdate),
        this.repository.onDidChangeStatus(changedPath => {
          if (changedPath === this.editorPath) scheduleUpdate();
        }),
        this.editor.onDidStopChanging(scheduleUpdate),
        this.editor.onDidChangePath(() => {
          this.editorPath = this.editor.getPath();
          this.buffer = this.editor.getBuffer();
          scheduleUpdate();
        }),
        atom.commands.add(
          this.editorElement,
          'git-diff:move-to-next-diff',
          this.moveToNextDiff.bind(this)
        ),
        atom.commands.add(
          this.editorElement,
          'git-diff:move-to-previous-diff',
          this.moveToPreviousDiff.bind(this)
        ),
        atom.config.onDidChange(
          'git-diff.showIconsInEditorGutter',
          updateIconDecoration
        ),
        atom.config.onDidChange('editor.showLineNumbers', updateIconDecoration),
        this.editorElement.onDidAttach(updateIconDecoration)
      );

      // Every time the repo is changed, the editor needs to be reinitialized.
      this.subscriptions.add(this._repoSubs);

      updateIconDecoration();
      scheduleUpdate();
    } else {
      this.destroyChildren();
      this.releaseChildren();
    }
  }

  moveToNextDiff() {
    const cursorLineNumber = this.editor.getCursorBufferPosition().row + 1;
    let nextDiffLineNumber = null;
    let firstDiffLineNumber = null;

    for (const { newStart } of this.diffs) {
      if (newStart > cursorLineNumber) {
        if (nextDiffLineNumber == null) nextDiffLineNumber = newStart - 1;

        nextDiffLineNumber = Math.min(newStart - 1, nextDiffLineNumber);
      }

      if (firstDiffLineNumber == null) firstDiffLineNumber = newStart - 1;

      firstDiffLineNumber = Math.min(newStart - 1, firstDiffLineNumber);
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

  moveToPreviousDiff() {
    const cursorLineNumber = this.editor.getCursorBufferPosition().row + 1;
    let previousDiffLineNumber = null;
    let lastDiffLineNumber = null;
    for (const { newStart } of this.diffs) {
      if (newStart < cursorLineNumber) {
        previousDiffLineNumber = Math.max(newStart - 1, previousDiffLineNumber);
      }
      lastDiffLineNumber = Math.max(newStart - 1, lastDiffLineNumber);
    }

    // Wrap around to the last diff in the file
    if (
      atom.config.get('git-diff.wrapAroundOnMoveToDiff') &&
      previousDiffLineNumber === null
    ) {
      previousDiffLineNumber = lastDiffLineNumber;
    }

    this.moveToLineNumber(previousDiffLineNumber);
  }

  updateIconDecoration() {
    const gutter = this.editorElement.querySelector('.gutter');
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

  moveToLineNumber(lineNumber) {
    if (lineNumber !== null) {
      this.editor.setCursorBufferPosition([lineNumber, 0]);
      this.editor.moveToFirstCharacterOfLine();
    }
  }

  scheduleUpdate() {
    // Use Chromium native requestAnimationFrame because it yields
    // to the browser, is standard and doesn't involve extra JS overhead.
    if (this._animationId) cancelAnimationFrame(this._animationId);

    this._animationId = requestAnimationFrame(this.updateDiffs);
  }

  /**
   * @describe Uses text markers in the target editor to visualize
   *   git modifications, additions, and deletions. The current algorithm
   *   just redraws the markers each call.
   */
  updateDiffs() {
    if (this.buffer.getLength() < MAX_BUFFER_LENGTH_TO_DIFF) {
      // Before we redraw the diffs, tear down the old markers.
      if (this.diffs)
        for (const diff of this.diffs) this.markers.get(diff).destroy();

      this.markers.clear();

      const text = this.buffer.getText();
      this.diffs = this.repository.getLineDiffs(this.editorPath, text);
      this.diffs = this.diffs || []; // Sanitize type to array.

      for (const diff of this.diffs) {
        const { newStart, oldLines, newLines } = diff;
        const startRow = newStart - 1;
        const endRow = newStart + newLines - 1;

        let mark;

        if (oldLines === 0 && newLines > 0) {
          mark = this.markRange(startRow, endRow, 'git-line-added');
        } else if (newLines === 0 && oldLines > 0) {
          if (startRow < 0) {
            mark = this.markRange(0, 0, 'git-previous-line-removed');
          } else {
            mark = this.markRange(startRow, startRow, 'git-line-removed');
          }
        } else {
          mark = this.markRange(startRow, endRow, 'git-line-modified');
        }

        this.markers.set(diff, mark);
      }
    }
  }

  markRange(startRow, endRow, klass) {
    const marker = this.editor.markBufferRange([[startRow, 0], [endRow, 0]], {
      invalidate: 'never'
    });
    this.editor.decorateMarker(marker, { type: 'line-number', class: klass });
    return marker;
  }
}
