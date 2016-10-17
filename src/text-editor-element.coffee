Grim = require 'grim'
{Emitter, CompositeDisposable} = require 'event-kit'
TextBuffer = require 'text-buffer'
TextEditorComponent = require './text-editor-component'

class TextEditorElement extends HTMLElement
  model: null
  componentDescriptor: null
  component: null
  attached: false
  tileSize: null
  focusOnAttach: false
  hasTiledRendering: true
  logicalDisplayBuffer: true

  createdCallback: ->
    # Use globals when the following instance variables aren't set.
    @themes = atom.themes
    @workspace = atom.workspace
    @assert = atom.assert
    @views = atom.views
    @styles = atom.styles

    @emitter = new Emitter
    @subscriptions = new CompositeDisposable

    @addEventListener 'focus', @focused.bind(this)
    @addEventListener 'blur', @blurred.bind(this)

    @classList.add('editor')
    @setAttribute('tabindex', -1)

  initializeContent: (attributes) ->
    Object.defineProperty(this, 'shadowRoot', {
      get: =>
        Grim.deprecate("""
        The contents of `atom-text-editor` elements are no longer encapsulated
        within a shadow DOM boundary. Please, stop using `shadowRoot` and access
        the editor contents directly instead.
        """)
        this
    })
    @rootElement = document.createElement('div')
    @rootElement.classList.add('editor--private')
    @appendChild(@rootElement)

  attachedCallback: ->
    @buildModel() unless @getModel()?
    @assert(@model.isAlive(), "Attaching a view for a destroyed editor")
    @mountComponent() unless @component?
    @listenForComponentEvents()
    @component.checkForVisibilityChange()
    if @hasFocus()
      @focused()
    @emitter.emit("did-attach")

  detachedCallback: ->
    @unmountComponent()
    @subscriptions.dispose()
    @subscriptions = new CompositeDisposable
    @emitter.emit("did-detach")

  listenForComponentEvents: ->
    @subscriptions.add @component.onDidChangeScrollTop =>
      @emitter.emit("did-change-scroll-top", arguments...)
    @subscriptions.add @component.onDidChangeScrollLeft =>
      @emitter.emit("did-change-scroll-left", arguments...)

  initialize: (model, {@views, @themes, @workspace, @assert, @styles}) ->
    throw new Error("Must pass a views parameter when initializing TextEditorElements") unless @views?
    throw new Error("Must pass a themes parameter when initializing TextEditorElements") unless @themes?
    throw new Error("Must pass a workspace parameter when initializing TextEditorElements") unless @workspace?
    throw new Error("Must pass an assert parameter when initializing TextEditorElements") unless @assert?
    throw new Error("Must pass a styles parameter when initializing TextEditorElements") unless @styles?

    @setModel(model)
    this

  setModel: (model) ->
    throw new Error("Model already assigned on TextEditorElement") if @model?
    return if model.isDestroyed()

    @model = model
    @model.setUpdatedSynchronously(@isUpdatedSynchronously())
    @initializeContent()
    @mountComponent()
    @addGrammarScopeAttribute()
    @addMiniAttribute() if @model.isMini()
    @addEncodingAttribute()
    @model.onDidChangeGrammar => @addGrammarScopeAttribute()
    @model.onDidChangeEncoding => @addEncodingAttribute()
    @model.onDidDestroy => @unmountComponent()
    @model.onDidChangeMini (mini) => if mini then @addMiniAttribute() else @removeMiniAttribute()
    @model

  getModel: ->
    @model ? @buildModel()

  buildModel: ->
    @setModel(@workspace.buildTextEditor(
      buffer: new TextBuffer(@textContent)
      softWrapped: false
      tabLength: 2
      softTabs: true
      mini: @hasAttribute('mini')
      lineNumberGutterVisible: not @hasAttribute('gutter-hidden')
      placeholderText: @getAttribute('placeholder-text')
    ))

  mountComponent: ->
    @component = new TextEditorComponent(
      hostElement: this
      editor: @model
      tileSize: @tileSize
      views: @views
      themes: @themes
      styles: @styles
      workspace: @workspace
      assert: @assert
    )
    @rootElement.appendChild(@component.getDomNode())
    inputNode = @component.hiddenInputComponent.getDomNode()
    inputNode.addEventListener 'focus', @focused.bind(this)
    inputNode.addEventListener 'blur', @inputNodeBlurred.bind(this)

  unmountComponent: ->
    if @component?
      @component.destroy()
      @component.getDomNode().remove()
      @component = null

  focused: (event) ->
    @component?.focused()

  blurred: (event) ->
    if event.relatedTarget is @component?.hiddenInputComponent.getDomNode()
      event.stopImmediatePropagation()
      return
    @component?.blurred()

  inputNodeBlurred: (event) ->
    if event.relatedTarget isnt this
      @dispatchEvent(new FocusEvent('blur', bubbles: false))

  addGrammarScopeAttribute: ->
    @dataset.grammar = @model.getGrammar()?.scopeName?.replace(/\./g, ' ')

  addMiniAttribute: ->
    @setAttributeNode(document.createAttribute("mini"))

  removeMiniAttribute: ->
    @removeAttribute("mini")

  addEncodingAttribute: ->
    @dataset.encoding = @model.getEncoding()

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

  setUpdatedSynchronously: (@updatedSynchronously) ->
    @model?.setUpdatedSynchronously(@updatedSynchronously)
    @updatedSynchronously

  isUpdatedSynchronously: -> @updatedSynchronously

  # Extended: Continuously reflows lines and line numbers. (Has performance overhead)
  #
  # * `continuousReflow` A {Boolean} indicating whether to keep reflowing or not.
  setContinuousReflow: (continuousReflow) ->
    @component?.setContinuousReflow(continuousReflow)

  # Extended: get the width of a character of text displayed in this element.
  #
  # Returns a {Number} of pixels.
  getDefaultCharacterWidth: ->
    @getModel().getDefaultCharWidth()

  # Extended: Get the maximum scroll top that can be applied to this element.
  #
  # Returns a {Number} of pixels.
  getMaxScrollTop: ->
    @component?.getMaxScrollTop()

  # Extended: Converts a buffer position to a pixel position.
  #
  # * `bufferPosition` An object that represents a buffer position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel position.
  pixelPositionForBufferPosition: (bufferPosition) ->
    @component.pixelPositionForBufferPosition(bufferPosition)

  # Extended: Converts a screen position to a pixel position.
  #
  # * `screenPosition` An object that represents a screen position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForScreenPosition: (screenPosition) ->
    @component.pixelPositionForScreenPosition(screenPosition)

  # Extended: Retrieves the number of the row that is visible and currently at the
  # top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    @getVisibleRowRange()[0]

  # Extended: Retrieves the number of the row that is visible and currently at the
  # bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    @getVisibleRowRange()[1]

  # Extended: call the given `callback` when the editor is attached to the DOM.
  #
  # * `callback` {Function}
  onDidAttach: (callback) ->
    @emitter.on("did-attach", callback)

  # Extended: call the given `callback` when the editor is detached from the DOM.
  #
  # * `callback` {Function}
  onDidDetach: (callback) ->
    @emitter.on("did-detach", callback)

  onDidChangeScrollTop: (callback) ->
    @emitter.on("did-change-scroll-top", callback)

  onDidChangeScrollLeft: (callback) ->
    @emitter.on("did-change-scroll-left", callback)

  setScrollLeft: (scrollLeft) ->
    @component.setScrollLeft(scrollLeft)

  setScrollRight: (scrollRight) ->
    @component.setScrollRight(scrollRight)

  setScrollTop: (scrollTop) ->
    @component.setScrollTop(scrollTop)

  setScrollBottom: (scrollBottom) ->
    @component.setScrollBottom(scrollBottom)

  # Essential: Scrolls the editor to the top
  scrollToTop: ->
    @setScrollTop(0)

  # Essential: Scrolls the editor to the bottom
  scrollToBottom: ->
    @setScrollBottom(Infinity)

  getScrollTop: ->
    @component?.getScrollTop() or 0

  getScrollLeft: ->
    @component?.getScrollLeft() or 0

  getScrollRight: ->
    @component?.getScrollRight() or 0

  getScrollBottom: ->
    @component?.getScrollBottom() or 0

  getScrollHeight: ->
    @component?.getScrollHeight() or 0

  getScrollWidth: ->
    @component?.getScrollWidth() or 0

  getVerticalScrollbarWidth: ->
    @component?.getVerticalScrollbarWidth() or 0

  getHorizontalScrollbarHeight: ->
    @component?.getHorizontalScrollbarHeight() or 0

  getVisibleRowRange: ->
    @component?.getVisibleRowRange() or [0, 0]

  intersectsVisibleRowRange: (startRow, endRow) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    not (endRow <= visibleStart or visibleEnd <= startRow)

  selectionIntersectsVisibleRowRange: (selection) ->
    {start, end} = selection.getScreenRange()
    @intersectsVisibleRowRange(start.row, end.row + 1)

  screenPositionForPixelPosition: (pixelPosition) ->
    @component.screenPositionForPixelPosition(pixelPosition)

  pixelRectForScreenRange: (screenRange) ->
    @component.pixelRectForScreenRange(screenRange)

  pixelRangeForScreenRange: (screenRange) ->
    @component.pixelRangeForScreenRange(screenRange)

  setWidth: (width) ->
    @style.width = (@component.getGutterWidth() + width) + "px"

  getWidth: ->
    @offsetWidth - @component.getGutterWidth()

  setHeight: (height) ->
    @style.height = height + "px"

  getHeight: ->
    @offsetHeight

  # Experimental: Invalidate the passed block {Decoration} dimensions, forcing
  # them to be recalculated and the surrounding content to be adjusted on the
  # next animation frame.
  #
  # * {blockDecoration} A {Decoration} representing the block decoration you
  # want to update the dimensions of.
  invalidateBlockDecorationDimensions: ->
    @component.invalidateBlockDecorationDimensions(arguments...)

module.exports = TextEditorElement = document.registerElement 'atom-text-editor', prototype: TextEditorElement.prototype
