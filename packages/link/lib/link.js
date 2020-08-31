const url = require('url');
const { shell } = require('electron');
const _ = require('underscore-plus');

const LINK_SCOPE_REGEX = /markup\.underline\.link/;

module.exports = {
  activate() {
    this.commandDisposable = atom.commands.add(
      'atom-text-editor',
      'link:open',
      () => this.openLink()
    );
  },

  deactivate() {
    this.commandDisposable.dispose();
  },

  openLink() {
    const editor = atom.workspace.getActiveTextEditor();
    if (editor == null) return;

    let link = this.linkUnderCursor(editor);
    if (link == null) return;

    if (editor.getGrammar().scopeName === 'source.gfm') {
      link = this.linkForName(editor, link);
    }

    const { protocol } = url.parse(link);
    if (protocol === 'http:' || protocol === 'https:' || protocol === 'atom:') {
      shell.openExternal(link);
    }
  },

  // Get the link under the cursor in the editor
  //
  // Returns a {String} link or undefined if no link found.
  linkUnderCursor(editor) {
    const cursorPosition = editor.getCursorBufferPosition();
    const link = this.linkAtPosition(editor, cursorPosition);
    if (link != null) return link;

    // Look for a link to the left of the cursor
    if (cursorPosition.column > 0) {
      return this.linkAtPosition(editor, cursorPosition.translate([0, -1]));
    }
  },

  // Get the link at the buffer position in the editor.
  //
  // Returns a {String} link or undefined if no link found.
  linkAtPosition(editor, bufferPosition) {
    const token = editor.tokenForBufferPosition(bufferPosition);
    if (
      token &&
      token.value &&
      token.scopes.some(scope => LINK_SCOPE_REGEX.test(scope))
    ) {
      return token.value;
    }
  },

  // Get the link for the given name.
  //
  // This is for Markdown links of the style:
  //
  // ```
  // [label][name]
  //
  // [name]: https://github.com
  // ```
  //
  // Returns a {String} link
  linkForName(editor, linkName) {
    let link = linkName;
    const regex = new RegExp(
      `^\\s*\\[${_.escapeRegExp(linkName)}\\]\\s*:\\s*(.+)$`,
      'g'
    );
    editor.backwardsScanInBufferRange(
      regex,
      [[0, 0], [Infinity, Infinity]],
      ({ match, stop }) => {
        link = match[1];
        stop();
      }
    );
    return link;
  }
};
