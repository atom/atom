const {Emitter} = require('atom')
const TextEditorComponent = require('./text-editor-component')
const dedent = require('dedent')

class TextEditorElement extends HTMLElement {
  initialize (component) {
    this.component = component
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

  createdCallback () {
    this.emitter = new Emitter()
    this.initialText = this.textContent
    this.tabIndex = -1
    this.addEventListener('focus', (event) => this.getComponent().didFocus(event))
    this.addEventListener('blur', (event) => this.getComponent().didBlur(event))
  }

  attachedCallback () {
    this.getComponent().didAttach()
    this.emitter.emit('did-attach')
    this.updateModelFromAttributes()
  }

  detachedCallback () {
    this.emitter.emit('did-detach')
    this.getComponent().didDetach()
  }

  attributeChangedCallback (name, oldValue, newValue) {
    if (this.component) {
      switch (name) {
        case 'mini':
          this.getModel().update({mini: newValue != null})
          break;
        case 'placeholder-text':
          this.getModel().update({placeholderText: newValue})
          break;
        case 'gutter-hidden':
          this.getModel().update({isVisible: newValue != null})
          break;
      }
    }
  }

  getModel () {
    return this.getComponent().props.model
  }

  setModel (model) {
    this.getComponent().update({model})
    this.updateModelFromAttributes()
  }

  updateModelFromAttributes () {
    const props = {
      mini: this.hasAttribute('mini'),
      placeholderText: this.getAttribute('placeholder-text'),
    }
    if (this.hasAttribute('gutter-hidden')) props.lineNumberGutterVisible = false

    this.getModel().update(props)
    if (this.initialText) this.getModel().setText(this.initialText)
  }

  onDidAttach (callback) {
    return this.emitter.on('did-attach', callback)
  }

  onDidDetach (callback) {
    return this.emitter.on('did-detach', callback)
  }

  setWidth (width) {
    this.style.width = this.getComponent().getGutterContainerWidth() + width + 'px'
  }

  getWidth () {
    this.offsetWidth - this.getComponent().getGutterContainerWidth()
  }

  setHeight (height) {
    this.style.height = height + 'px'
  }

  getHeight () {
    return this.offsetHeight
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

  getMaxScrollTop () {
    return this.getComponent().getMaxScrollTop()
  }

  getScrollTop () {
    return this.getComponent().getScrollTop()
  }

  setScrollTop (scrollTop) {
    this.getComponent().setScrollTop(scrollTop)
  }

  getScrollLeft () {
    return this.getComponent().getScrollLeft()
  }

  setScrollLeft (scrollLeft) {
    this.getComponent().setScrollLeft(scrollLeft)
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

  isUpdatedSynchronously () {
    return this.component ? this.component.updatedSynchronously : this.updatedSynchronously
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
