'use babel';

import _ from 'underscore-plus';
import { CompositeDisposable, Disposable } from 'atom';
import { Selector } from './selector';
import StatusBarItem from './status-bar-item';
import helpers from './helpers';

const LineEndingRegExp = /\r\n|\n/g;

// the following regular expression is executed natively via the `substring` package,
// where `\A` corresponds to the beginning of the string.
// More info: https://github.com/atom/line-ending-selector/pull/56
// eslint-disable-next-line no-useless-escape
const LFRegExp = /(\A|[^\r])\n/g;
const CRLFRegExp = /\r\n/g;

let disposables = null;

export function activate() {
  disposables = new CompositeDisposable();
  let selectorDisposable;
  let selector;

  disposables.add(
    atom.commands.add('atom-text-editor', {
      'line-ending-selector:show': () => {
        // Initiating Selector object - called only once when `line-ending-selector:show` is called
        if (!selectorDisposable) {
          // make a Selector object
          selector = new Selector([
            { name: 'LF', value: '\n' },
            { name: 'CRLF', value: '\r\n' }
          ]);
          // Add disposable for selector
          selectorDisposable = new Disposable(() => selector.dispose());
          disposables.add(selectorDisposable);
        }

        selector.show();
      },

      'line-ending-selector:convert-to-LF': event => {
        const editorElement = event.target.closest('atom-text-editor');
        setLineEnding(editorElement.getModel(), '\n');
      },

      'line-ending-selector:convert-to-CRLF': event => {
        const editorElement = event.target.closest('atom-text-editor');
        setLineEnding(editorElement.getModel(), '\r\n');
      }
    })
  );
}

export function deactivate() {
  disposables.dispose();
}

export function consumeStatusBar(statusBar) {
  let statusBarItem = new StatusBarItem();
  let currentBufferDisposable = null;
  let tooltipDisposable = null;

  const updateTile = _.debounce(buffer => {
    getLineEndings(buffer).then(lineEndings => {
      if (lineEndings.size === 0) {
        let defaultLineEnding = getDefaultLineEnding();
        buffer.setPreferredLineEnding(defaultLineEnding);
        lineEndings = new Set().add(defaultLineEnding);
      }
      statusBarItem.setLineEndings(lineEndings);
    });
  }, 0);

  disposables.add(
    atom.workspace.observeActiveTextEditor(editor => {
      if (currentBufferDisposable) currentBufferDisposable.dispose();

      if (editor && editor.getBuffer) {
        let buffer = editor.getBuffer();
        updateTile(buffer);
        currentBufferDisposable = buffer.onDidChange(({ oldText, newText }) => {
          if (!statusBarItem.hasLineEnding('\n')) {
            if (newText.indexOf('\n') >= 0) {
              updateTile(buffer);
            }
          } else if (!statusBarItem.hasLineEnding('\r\n')) {
            if (newText.indexOf('\r\n') >= 0) {
              updateTile(buffer);
            }
          } else if (oldText.indexOf('\n')) {
            updateTile(buffer);
          }
        });
      } else {
        statusBarItem.setLineEndings(new Set());
        currentBufferDisposable = null;
      }

      if (tooltipDisposable) {
        disposables.remove(tooltipDisposable);
        tooltipDisposable.dispose();
      }
      tooltipDisposable = atom.tooltips.add(statusBarItem.element, {
        title() {
          return `File uses ${statusBarItem.description()} line endings`;
        }
      });
      disposables.add(tooltipDisposable);
    })
  );

  disposables.add(
    new Disposable(() => {
      if (currentBufferDisposable) currentBufferDisposable.dispose();
    })
  );

  statusBarItem.onClick(() => {
    const editor = atom.workspace.getActiveTextEditor();
    atom.commands.dispatch(
      atom.views.getView(editor),
      'line-ending-selector:show'
    );
  });

  let tile = statusBar.addRightTile({ item: statusBarItem, priority: 200 });
  disposables.add(new Disposable(() => tile.destroy()));
}

function getDefaultLineEnding() {
  switch (atom.config.get('line-ending-selector.defaultLineEnding')) {
    case 'LF':
      return '\n';
    case 'CRLF':
      return '\r\n';
    case 'OS Default':
    default:
      return helpers.getProcessPlatform() === 'win32' ? '\r\n' : '\n';
  }
}

function getLineEndings(buffer) {
  if (typeof buffer.find === 'function') {
    return Promise.all([buffer.find(LFRegExp), buffer.find(CRLFRegExp)]).then(
      ([hasLF, hasCRLF]) => {
        const result = new Set();
        if (hasLF) result.add('\n');
        if (hasCRLF) result.add('\r\n');
        return result;
      }
    );
  } else {
    return new Promise(resolve => {
      const result = new Set();
      for (let i = 0; i < buffer.getLineCount() - 1; i++) {
        result.add(buffer.lineEndingForRow(i));
      }
      resolve(result);
    });
  }
}

export function setLineEnding(item, lineEnding) {
  if (item && item.getBuffer) {
    let buffer = item.getBuffer();
    buffer.setPreferredLineEnding(lineEnding);
    buffer.setText(buffer.getText().replace(LineEndingRegExp, lineEnding));
  }
}
