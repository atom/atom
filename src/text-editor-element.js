const {Emitter} = require('atom')
const Grim = require('grim')
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

  get rootElement () {
    Grim.deprecate(dedent`
      The contents of \`atom-text-editor\` elements are no longer encapsulated
      within a shadow DOM boundary. Please, stop using \`rootElement\` and access
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
          break
        case 'placeholder-text':
          this.getModel().update({placeholderText: newValue})
          break
        case 'gutter-hidden':
          this.getModel().update({isVisible: newValue != null})
          break
      }
    }
  }

  // Extended: Get a promise that resolves the next time the element's DOM
  // is updated in any way.
  //
  // This can be useful when you've made a change to the model and need to
  // be sure this change has been flushed to the DOM.
  //
  // Returns a {Promise}.
  getNextUpdatePromise () {
    return this.getComponent().getNextUpdatePromise()
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
    }
    if (this.hasAttribute('placeholder-text')) props.placeholderText = this.getAttribute('placeholder-text')
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
    return this.getComponent().getScrollContainerWidth()
  }

  setHeight (height) {
    this.style.height = height + 'px'
  }

  getHeight () {
    return this.getComponent().getScrollContainerHeight()
  }

  onDidChangeScrollLeft (callback) {
    return this.emitter.on('did-change-scroll-left', callback)
  }

  onDidChangeScrollTop (callback) {
    return this.emitter.on('did-change-scroll-top', callback)
  }

  // Deprecated: get the width of an `x` character displayed in this element.
  //
  // Returns a {Number} of pixels.
  getDefaultCharacterWidth () {
    return this.getComponent().getBaseCharacterWidth()
  }

  // Extended: get the width of an `x` character displayed in this element.
  //
  // Returns a {Number} of pixels.
  getBaseCharacterWidth () {
    return this.getComponent().getBaseCharacterWidth()
  }
  getMaxScrollTop () {
    return this.getComponent().getMaxScrollTop()
  }

  getScrollTop () {
    return this.getComponent().getScrollTop()
  }

  setScrollTop (scrollTop) {
    const component = this.getComponent()
    component.setScrollTop(scrollTop)
    component.scheduleUpdate()
  }

  getScrollLeft () {
    return this.getComponent().getScrollLeft()
  }

  setScrollLeft (scrollLeft) {
    const component = this.getComponent()
    component.setScrollLeft(scrollLeft)
    component.scheduleUpdate()
  }

  hasFocus () {
    return this.getComponent().focused
  }

  // Extended: Converts a buffer position to a pixel position.
  //
  // * `bufferPosition` A {Point}-like object that represents a buffer position.
  //
  // Be aware that calling this method with a column that does not translate
  // to column 0 on screen could cause a synchronous DOM update in order to
  // measure the requested horizontal pixel position if it isn't already
  // cached.
  //
  // Returns an {Object} with two values: `top` and `left`, representing the
  // pixel position.
  pixelPositionForBufferPosition (bufferPosition) {
    const screenPosition = this.getModel().screenPositionForBufferPosition(bufferPosition)
    return this.getComponent().pixelPositionForScreenPositionSync(screenPosition)
  }

  // Extended: Converts a screen position to a pixel position.
  //
  // * `screenPosition` A {Point}-like object that represents a buffer position.
  //
  // Be aware that calling this method with a non-zero column value could
  // cause a synchronous DOM update in order to measure the requested
  // horizontal pixel position if it isn't already cached.
  //
  // Returns an {Object} with two values: `top` and `left`, representing the
  // pixel position.
  pixelPositionForScreenPosition (screenPosition) {
    screenPosition = this.getModel().clipScreenPosition(screenPosition)
    return this.getComponent().pixelPositionForScreenPositionSync(screenPosition)
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
