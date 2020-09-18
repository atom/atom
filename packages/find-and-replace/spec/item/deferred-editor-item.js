// An active workspace item that embeds an AtomTextEditor we wish to expose to Find and Replace that does not become
// available until some time after the item is activated.

const etch = require('etch');
const $ = etch.dom;

const { TextEditor, Emitter } = require('atom');

class DeferredEditorItem {
  static opener(u) {
    if (u === DeferredEditorItem.uri) {
      return new DeferredEditorItem();
    } else {
      return undefined;
    }
  }

  constructor() {
    this.editorShown = false;
    this.emitter = new Emitter();

    etch.initialize(this);
  }

  render() {
    if (this.editorShown) {
      return (
        $.div({className: 'wrapper'},
          etch.dom(TextEditor, {ref: 'theEditor'})
        )
      )
    } else {
      return (
        $.div({className: 'wrapper'}, 'Empty')
      )
    }
  }

  update() {
    return etch.update(this)
  }

  observeEmbeddedTextEditor(cb) {
    if (this.editorShown) {
      cb(this.refs.theEditor)
    }
    return this.emitter.on('did-change-embedded-text-editor', cb)
  }

  async showEditor() {
    const wasShown = this.editorShown
    this.editorShown = true
    await this.update()
    if (!wasShown) {
      this.emitter.emit('did-change-embedded-text-editor', this.refs.theEditor)
    }
  }

  async hideEditor() {
    const wasShown = this.editorShown
    this.editorShown = false
    await this.update()
    if (wasShown) {
      this.emitter.emit('did-change-embedded-text-editor', null)
    }
  }
}

DeferredEditorItem.uri = 'atom://find-and-replace/spec/deferred-editor'

module.exports = DeferredEditorItem
