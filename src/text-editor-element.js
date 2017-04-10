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

  detachedCallback () {
    this.getComponent().didDetach()
  }

  getModel () {
    return this.getComponent().props.model
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

  hasFocus () {
    return this.getComponent().focused
  }

  getComponent () {
    if (!this.component) this.component = new TextEditorComponent({
      element: this,
      updatedSynchronously: this.updatedSynchronously
    })
    return this.component
  }

  setUpdatedSynchronously (updatedSynchronously) {
    this.updatedSynchronously = updatedSynchronously
    if (this.component) this.component.updatedSynchronously = updatedSynchronously
    return updatedSynchronously
  }

  // Experimental: Invalidate the passed block {Decoration}'s dimensions,
  // forcing them to be recalculated and the surrounding content to be adjusted
  // on the next animation frame.
  //
  // * {blockDecoration} A {Decoration} representing the block decoration you
  // want to update the dimensions of.
  invalidateBlockDecorationDimensions () {
    if (this.component) {
      this.component.invalidateBlockDecorationDimensions(...arguments)
    }
  }
}

module.exports =
document.registerElement('atom-text-editor', {
  prototype: TextEditorElement.prototype
})
