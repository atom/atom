const {Emitter} = require('atom')
const TextEditorComponent = require('./text-editor-component')
const dedent = require('dedent')

class TextEditorElement extends HTMLElement {
  initialize (component) {
    this.component = component
    this.emitter = new Emitter()
    return this
  }

  get shadowRoot () {
    Grim.deprecate(dedent`
      The contents of \`atom-text-editor\` elements are no longer encapsulated
      within a shadow DOM boundary. Please, stop using \`shadowRoot\` and access
      the editor contents directly instead.
    `)

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
    return this.emitter.on('did-change-scroll-top', callback)
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
    if (!this.component) {
      this.component = new TextEditorComponent({
        element: this,
        updatedSynchronously: this.updatedSynchronously
      })
    }

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
