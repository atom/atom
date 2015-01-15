{View, $} = require 'space-pen'
React = require 'react-atom-fork'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
TextEditor = require './text-editor'
TextEditorElement = require './text-editor-element'
TextEditorComponent = require './text-editor-component'
{deprecate} = require 'grim'

# Deprecated: Represents the entire visual pane in Atom.
#
# The TextEditorView manages the {TextEditor}, which manages the file buffers.
# `TextEditorView` is intentionally sparse. Most of the things you'll want
# to do are on {TextEditor}.
#
# ## Examples
#
# Requiring in packages
#
# ```coffee
# {TextEditorView} = require 'atom'
#
# miniEditorView = new TextEditorView(mini: true)
# ```
#
# Iterating over the open editor views
#
# ```coffee
# for editorView in atom.workspaceView.getEditorViews()
#   console.log(editorView.getModel().getPath())
# ```
#
# Subscribing to every current and future editor
#
# ```coffee
# atom.workspace.eachEditorView (editorView) ->
#   console.log(editorView.getModel().getPath())
# ```
module.exports =
class TextEditorView extends View
  # The constructor for setting up an `TextEditorView` instance.
  #
  # * `modelOrParams` Either an {TextEditor}, or an object with one property, `mini`.
  #    If `mini` is `true`, a "miniature" `TextEditor` is constructed.
  #    Typically, this is ideal for scenarios where you need an Atom editor,
  #    but without all the chrome, like scrollbars, gutter, _e.t.c._.
  #
  constructor: (modelOrParams, props) ->
    # Handle direct construction with an editor or params
    unless modelOrParams instanceof HTMLElement
      if modelOrParams instanceof TextEditor
        model = modelOrParams
      else
        {editor, mini, placeholderText, attributes} = modelOrParams
        model = editor ? new TextEditor
          buffer: new TextBuffer
          softWrapped: false
          tabLength: 2
          softTabs: true
          mini: mini
          placeholderText: placeholderText

      element = new TextEditorElement
      element.lineOverdrawMargin = props?.lineOverdrawMargin
      element.setAttribute(name, value) for name, value of attributes if attributes?
      element.setModel(model)
      return element.__spacePenView

    # Handle construction with an element
    @element = modelOrParams
    super

  setModel: (@model) ->
    @editor = @model

    @root = $(@element.rootElement)

    @scrollView = @root.find('.scroll-view')

    if atom.config.get('editor.useShadowDOM')
      @underlayer = $("<div class='underlayer'></div>").appendTo(this)
      @overlayer = $("<div class='overlayer'></div>").appendTo(this)
    else
      @underlayer = @find('.highlights').addClass('underlayer')
      @overlayer = @find('.lines').addClass('overlayer')

    @hiddenInput = @root.find('.hidden-input')

    @hiddenInput.on = (args...) =>
      args[0] = 'blur' if args[0] is 'focusout'
      $::on.apply(this, args)

    @subscribe atom.config.observe 'editor.showLineNumbers', =>
      @gutter = @root.find('.gutter')

      @gutter.removeClassFromAllLines = (klass) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        @gutter.find('.line-number').removeClass(klass)

      @gutter.getLineNumberElement = (bufferRow) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        @gutter.find("[data-buffer-row='#{bufferRow}']")

      @gutter.addClassToLine = (bufferRow, klass) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        lines = @gutter.find("[data-buffer-row='#{bufferRow}']")
        lines.addClass(klass)
        lines.length > 0

  find: ->
    shadowResult = @root.find.apply(@root, arguments)
    if shadowResult.length > 0
      shadowResult
    else
      super

  # Public: Get the underlying editor model for this view.
  #
  # Returns an {TextEditor}
  getModel: -> @model

  getEditor: -> @model

  Object.defineProperty @::, 'lineHeight', get: -> @model.getLineHeightInPixels()
  Object.defineProperty @::, 'charWidth', get: -> @model.getDefaultCharWidth()
  Object.defineProperty @::, 'firstRenderedScreenRow', get: -> @component.getRenderedRowRange()[0]
  Object.defineProperty @::, 'lastRenderedScreenRow', get: -> @component.getRenderedRowRange()[1]
  Object.defineProperty @::, 'active', get: -> @is(@getPaneView()?.activeView)
  Object.defineProperty @::, 'isFocused', get: -> document.activeElement is @element or document.activeElement is @element.component?.refs.input.getDOMNode()
  Object.defineProperty @::, 'mini', get: -> @model?.isMini()
  Object.defineProperty @::, 'component', get: -> @element?.component

  afterAttach: (onDom) ->
    return unless onDom
    return if @attached
    @attached = true
    @trigger 'editor:attached', [this]

  beforeRemove: ->
    @trigger 'editor:detached', [this]
    @trigger 'editor:will-be-removed', [this]
    @attached = false

  remove: (selector, keepData) ->
    @model.destroy() unless keepData
    super

  scrollTop: (scrollTop) ->
    if scrollTop?
      @model.setScrollTop(scrollTop)
    else
      @model.getScrollTop()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @model.setScrollLeft(scrollLeft)
    else
      @model.getScrollLeft()

  scrollToBottom: ->
    deprecate 'Use TextEditor::scrollToBottom instead. You can get the editor via editorView.getModel()'
    @model.setScrollBottom(Infinity)

  scrollToScreenPosition: (screenPosition, options) ->
    deprecate 'Use TextEditor::scrollToScreenPosition instead. You can get the editor via editorView.getModel()'
    @model.scrollToScreenPosition(screenPosition, options)

  scrollToBufferPosition: (bufferPosition, options) ->
    deprecate 'Use TextEditor::scrollToBufferPosition instead. You can get the editor via editorView.getModel()'
    @model.scrollToBufferPosition(bufferPosition, options)

  scrollToCursorPosition: ->
    deprecate 'Use TextEditor::scrollToCursorPosition instead. You can get the editor via editorView.getModel()'
    @model.scrollToCursorPosition()

  pixelPositionForBufferPosition: (bufferPosition) ->
    deprecate 'Use TextEditorElement::pixelPositionForBufferPosition instead. You can get the editor via editorView.getModel()'
    @model.pixelPositionForBufferPosition(bufferPosition, true)

  pixelPositionForScreenPosition: (screenPosition) ->
    deprecate 'Use TextEditorElement::pixelPositionForScreenPosition instead. You can get the editor via editorView.getModel()'
    @model.pixelPositionForScreenPosition(screenPosition, true)

  appendToLinesView: (view) ->
    view.css('position', 'absolute')
    view.css('z-index', 1)
    @overlayer.append(view)

  unmountComponent: ->
    React.unmountComponentAtNode(@element) if @component.isMounted()

  splitLeft: ->
    deprecate """
      Use Pane::splitLeft instead.
      To duplicate this editor into the split use:
      editorView.getPaneView().getModel().splitLeft(copyActiveItem: true)
    """
    pane = @getPaneView()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  splitRight: ->
    deprecate """
      Use Pane::splitRight instead.
      To duplicate this editor into the split use:
      editorView.getPaneView().getModel().splitRight(copyActiveItem: true)
    """
    pane = @getPaneView()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  splitUp: ->
    deprecate """
      Use Pane::splitUp instead.
      To duplicate this editor into the split use:
      editorView.getPaneView().getModel().splitUp(copyActiveItem: true)
    """
    pane = @getPaneView()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  splitDown: ->
    deprecate """
      Use Pane::splitDown instead.
      To duplicate this editor into the split use:
      editorView.getPaneView().getModel().splitDown(copyActiveItem: true)
    """
    pane = @getPaneView()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  # Public: Get this {TextEditorView}'s {PaneView}.
  #
  # Returns a {PaneView}
  getPaneView: ->
    @parent('.item-views').parents('atom-pane').view()
  getPane: ->
    deprecate 'Use TextEditorView::getPaneView() instead'
    @getPaneView()

  show: ->
    super
    @component?.checkForVisibilityChange()

  hide: ->
    super
    @component?.checkForVisibilityChange()

  pageDown: ->
    deprecate('Use editorView.getModel().pageDown()')
    @model.pageDown()

  pageUp: ->
    deprecate('Use editorView.getModel().pageUp()')
    @model.pageUp()

  getFirstVisibleScreenRow: ->
    deprecate 'Use TextEditorElement::getFirstVisibleScreenRow instead.'
    @model.getFirstVisibleScreenRow(true)

  getLastVisibleScreenRow: ->
    deprecate 'Use TextEditor::getLastVisibleScreenRow instead. You can get the editor via editorView.getModel()'
    @model.getLastVisibleScreenRow()

  getFontFamily: ->
    deprecate 'This is going away. Use atom.config.get("editor.fontFamily") instead'
    @component?.getFontFamily()

  setFontFamily: (fontFamily) ->
    deprecate 'This is going away. Use atom.config.set("editor.fontFamily", "my-font") instead'
    @component?.setFontFamily(fontFamily)

  getFontSize: ->
    deprecate 'This is going away. Use atom.config.get("editor.fontSize") instead'
    @component?.getFontSize()

  setFontSize: (fontSize) ->
    deprecate 'This is going away. Use atom.config.set("editor.fontSize", 12) instead'
    @component?.setFontSize(fontSize)

  setLineHeight: (lineHeight) ->
    deprecate 'This is going away. Use atom.config.set("editor.lineHeight", 1.5) instead'
    @component.setLineHeight(lineHeight)

  setWidthInChars: (widthInChars) ->
    @component.getDOMNode().style.width = (@model.getDefaultCharWidth() * widthInChars) + 'px'

  setShowIndentGuide: (showIndentGuide) ->
    deprecate 'This is going away. Use atom.config.set("editor.showIndentGuide", true|false) instead'
    @component.setShowIndentGuide(showIndentGuide)

  setSoftWrap: (softWrapped) ->
    deprecate 'Use TextEditor::setSoftWrapped instead. You can get the editor via editorView.getModel()'
    @model.setSoftWrapped(softWrapped)

  setShowInvisibles: (showInvisibles) ->
    deprecate 'This is going away. Use atom.config.set("editor.showInvisibles", true|false) instead'
    @component.setShowInvisibles(showInvisibles)

  getText: ->
    @model.getText()

  setText: (text) ->
    @model.setText(text)

  insertText: (text) ->
    @model.insertText(text)

  isInputEnabled: ->
    @component.isInputEnabled()

  setInputEnabled: (inputEnabled) ->
    @component.setInputEnabled(inputEnabled)

  requestDisplayUpdate: ->
    deprecate('Please remove from your code. ::requestDisplayUpdate no longer does anything')

  updateDisplay: ->
    deprecate('Please remove from your code. ::updateDisplay no longer does anything')

  resetDisplay: ->
    deprecate('Please remove from your code. ::resetDisplay no longer does anything')

  redraw: ->
    deprecate('Please remove from your code. ::redraw no longer does anything')

  setPlaceholderText: (placeholderText) ->
    deprecate('Use TextEditor::setPlaceholderText instead. eg. editorView.getModel().setPlaceholderText(text)')
    @model.setPlaceholderText(placeholderText)

  lineElementForScreenRow: (screenRow) ->
    $(@component.lineNodeForScreenRow(screenRow))
