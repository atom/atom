const { Emitter, Range } = require('atom');
const Grim = require('grim');
const TextEditorComponent = require('./text-editor-component');
const dedent = require('dedent');

class TextEditorElement extends HTMLElement {
  initialize(component) {
    this.component = component;
    return this;
  }

  get shadowRoot() {
    Grim.deprecate(dedent`
      The contents of \`atom-text-editor\` elements are no longer encapsulated
      within a shadow DOM boundary. Please, stop using \`shadowRoot\` and access
      the editor contents directly instead.
    `);

    return this;
  }

  get rootElement() {
    Grim.deprecate(dedent`
      The contents of \`atom-text-editor\` elements are no longer encapsulated
      within a shadow DOM boundary. Please, stop using \`rootElement\` and access
      the editor contents directly instead.
    `);

    return this;
  }

  constructor() {
    super();
    this.emitter = new Emitter();
    this.initialText = this.textContent;
    if (this.tabIndex == null) this.tabIndex = -1;
    this.addEventListener('focus', event =>
      this.getComponent().didFocus(event)
    );
    this.addEventListener('blur', event => this.getComponent().didBlur(event));
  }

  connectedCallback() {
    this.getComponent().didAttach();
    this.emitter.emit('did-attach');
  }

  disconnectedCallback() {
    this.emitter.emit('did-detach');
    this.getComponent().didDetach();
  }

  static get observedAttributes() {
    return ['mini', 'placeholder-text', 'gutter-hidden', 'readonly'];
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (this.component) {
      switch (name) {
        case 'mini':
          this.getModel().update({ mini: newValue != null });
          break;
        case 'placeholder-text':
          this.getModel().update({ placeholderText: newValue });
          break;
        case 'gutter-hidden':
          this.getModel().update({ lineNumberGutterVisible: newValue == null });
          break;
        case 'readonly':
          this.getModel().update({ readOnly: newValue != null });
          break;
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
  getNextUpdatePromise() {
    return this.getComponent().getNextUpdatePromise();
  }

  getModel() {
    return this.getComponent().props.model;
  }

  setModel(model) {
    this.getComponent().update({ model });
    this.updateModelFromAttributes();
  }

  updateModelFromAttributes() {
    const props = { mini: this.hasAttribute('mini') };
    if (this.hasAttribute('placeholder-text'))
      props.placeholderText = this.getAttribute('placeholder-text');
    if (this.hasAttribute('gutter-hidden'))
      props.lineNumberGutterVisible = false;

    this.getModel().update(props);
    if (this.initialText) this.getModel().setText(this.initialText);
  }

  onDidAttach(callback) {
    return this.emitter.on('did-attach', callback);
  }

  onDidDetach(callback) {
    return this.emitter.on('did-detach', callback);
  }

  measureDimensions() {
    this.getComponent().measureDimensions();
  }

  setWidth(width) {
    this.style.width =
      this.getComponent().getGutterContainerWidth() + width + 'px';
  }

  getWidth() {
    return this.getComponent().getScrollContainerWidth();
  }

  setHeight(height) {
    this.style.height = height + 'px';
  }

  getHeight() {
    return this.getComponent().getScrollContainerHeight();
  }

  onDidChangeScrollLeft(callback) {
    return this.emitter.on('did-change-scroll-left', callback);
  }

  onDidChangeScrollTop(callback) {
    return this.emitter.on('did-change-scroll-top', callback);
  }

  // Deprecated: get the width of an `x` character displayed in this element.
  //
  // Returns a {Number} of pixels.
  getDefaultCharacterWidth() {
    return this.getComponent().getBaseCharacterWidth();
  }

  // Extended: get the width of an `x` character displayed in this element.
  //
  // Returns a {Number} of pixels.
  getBaseCharacterWidth() {
    return this.getComponent().getBaseCharacterWidth();
  }

  getMaxScrollTop() {
    return this.getComponent().getMaxScrollTop();
  }

  getScrollHeight() {
    return this.getComponent().getScrollHeight();
  }

  getScrollWidth() {
    return this.getComponent().getScrollWidth();
  }

  getVerticalScrollbarWidth() {
    return this.getComponent().getVerticalScrollbarWidth();
  }

  getHorizontalScrollbarHeight() {
    return this.getComponent().getHorizontalScrollbarHeight();
  }

  getScrollTop() {
    return this.getComponent().getScrollTop();
  }

  setScrollTop(scrollTop) {
    const component = this.getComponent();
    component.setScrollTop(scrollTop);
    component.scheduleUpdate();
  }

  getScrollBottom() {
    return this.getComponent().getScrollBottom();
  }

  setScrollBottom(scrollBottom) {
    return this.getComponent().setScrollBottom(scrollBottom);
  }

  getScrollLeft() {
    return this.getComponent().getScrollLeft();
  }

  setScrollLeft(scrollLeft) {
    const component = this.getComponent();
    component.setScrollLeft(scrollLeft);
    component.scheduleUpdate();
  }

  getScrollRight() {
    return this.getComponent().getScrollRight();
  }

  setScrollRight(scrollRight) {
    return this.getComponent().setScrollRight(scrollRight);
  }

  // Essential: Scrolls the editor to the top.
  scrollToTop() {
    this.setScrollTop(0);
  }

  // Essential: Scrolls the editor to the bottom.
  scrollToBottom() {
    this.setScrollTop(Infinity);
  }

  hasFocus() {
    return this.getComponent().focused;
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
  pixelPositionForBufferPosition(bufferPosition) {
    const screenPosition = this.getModel().screenPositionForBufferPosition(
      bufferPosition
    );
    return this.getComponent().pixelPositionForScreenPosition(screenPosition);
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
  pixelPositionForScreenPosition(screenPosition) {
    screenPosition = this.getModel().clipScreenPosition(screenPosition);
    return this.getComponent().pixelPositionForScreenPosition(screenPosition);
  }

  screenPositionForPixelPosition(pixelPosition) {
    return this.getComponent().screenPositionForPixelPosition(pixelPosition);
  }

  pixelRectForScreenRange(range) {
    range = Range.fromObject(range);

    const start = this.pixelPositionForScreenPosition(range.start);
    const end = this.pixelPositionForScreenPosition(range.end);
    const lineHeight = this.getComponent().getLineHeight();

    return {
      top: start.top,
      left: start.left,
      height: end.top + lineHeight - start.top,
      width: end.left - start.left
    };
  }

  pixelRangeForScreenRange(range) {
    range = Range.fromObject(range);
    return {
      start: this.pixelPositionForScreenPosition(range.start),
      end: this.pixelPositionForScreenPosition(range.end)
    };
  }

  getComponent() {
    if (!this.component) {
      this.component = new TextEditorComponent({
        element: this,
        mini: this.hasAttribute('mini'),
        updatedSynchronously: this.updatedSynchronously,
        readOnly: this.hasAttribute('readonly')
      });
      this.updateModelFromAttributes();
    }

    return this.component;
  }

  setUpdatedSynchronously(updatedSynchronously) {
    this.updatedSynchronously = updatedSynchronously;
    if (this.component)
      this.component.updatedSynchronously = updatedSynchronously;
    return updatedSynchronously;
  }

  isUpdatedSynchronously() {
    return this.component
      ? this.component.updatedSynchronously
      : this.updatedSynchronously;
  }

  // Experimental: Invalidate the passed block {Decoration}'s dimensions,
  // forcing them to be recalculated and the surrounding content to be adjusted
  // on the next animation frame.
  //
  // * {blockDecoration} A {Decoration} representing the block decoration you
  // want to update the dimensions of.
  invalidateBlockDecorationDimensions() {
    this.getComponent().invalidateBlockDecorationDimensions(...arguments);
  }

  setFirstVisibleScreenRow(row) {
    this.getModel().setFirstVisibleScreenRow(row);
  }

  getFirstVisibleScreenRow() {
    return this.getModel().getFirstVisibleScreenRow();
  }

  getLastVisibleScreenRow() {
    return this.getModel().getLastVisibleScreenRow();
  }

  getVisibleRowRange() {
    return this.getModel().getVisibleRowRange();
  }

  intersectsVisibleRowRange(startRow, endRow) {
    return !(
      endRow <= this.getFirstVisibleScreenRow() ||
      this.getLastVisibleScreenRow() <= startRow
    );
  }

  selectionIntersectsVisibleRowRange(selection) {
    const { start, end } = selection.getScreenRange();
    return this.intersectsVisibleRowRange(start.row, end.row + 1);
  }

  setFirstVisibleScreenColumn(column) {
    return this.getModel().setFirstVisibleScreenColumn(column);
  }

  getFirstVisibleScreenColumn() {
    return this.getModel().getFirstVisibleScreenColumn();
  }

  static createTextEditorElement() {
    return document.createElement('atom-text-editor');
  }
}

window.customElements.define('atom-text-editor', TextEditorElement);

module.exports = TextEditorElement;
