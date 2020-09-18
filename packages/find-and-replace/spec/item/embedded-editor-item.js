// An active workspace item that embeds an AtomTextEditor we wish to expose to Find and Replace.

const etch = require('etch');
const $ = etch.dom;

const { TextEditor } = require('atom');

class EmbeddedEditorItem {
  static opener(u) {
    if (u === EmbeddedEditorItem.uri) {
      return new EmbeddedEditorItem();
    } else {
      return undefined;
    }
  }

  constructor() {
    etch.initialize(this);
  }

  render() {
    return (
      $.div({className: 'wrapper'},
        etch.dom(TextEditor, {ref: 'theEditor'})
      )
    )
  }

  update() {}

  getEmbeddedTextEditor() {
    return this.refs.theEditor
  }
}

EmbeddedEditorItem.uri = 'atom://find-and-replace/spec/embedded-editor'

module.exports = EmbeddedEditorItem
