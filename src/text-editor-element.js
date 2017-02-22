const {Emitter} = require('atom')
const TextEditorComponent = require('./text-editor-component')

class TextEditorElement extends HTMLElement {
  initialize (component) {
    this.component = component
    this.emitter = new Emitter()
    return this
  }

  attachedCallback () {
    this.getComponent().didAttach()
    this.emitter.emit('did-attach')
  }

  getModel () {
    return this.getComponent().getModel()
  }

  setModel (model) {
    this.getComponent().setModel(model)
  }

  onDidAttach (callback) {
    return this.emitter.on('did-attach', callback)
  }

  onDidChangeScrollLeft (callback) {
    return this.emitter.on('did-change-scroll-left', callback)
  }

  onDidChangeScrollTop (callback) {
    return this.emitter.on('did-change-scrol-top', callback)
  }

  getDefaultCharacterWidth () {
    return this.getComponent().getBaseCharacterWidth()
  }

  getScrollTop () {
    return this.getComponent().getScrollTop()
  }

  getScrollLeft () {
    return this.getComponent().getScrollLeft()
  }

  getComponent () {
    if (!this.component) this.component = new TextEditorComponent({element: this})
    return this.component
  }
}

module.exports =
document.registerElement('atom-text-editor', {
  prototype: TextEditorElement.prototype
})
