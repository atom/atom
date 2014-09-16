{View, $} = require 'space-pen'
React = require 'react-atom-fork'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
Editor = require './editor'
EditorComponent = require './editor-component'
{deprecate} = require 'grim'

# Public: Represents the entire visual pane in Atom.
#
# The EditorView manages the {Editor}, which manages the file buffers.
#
# ## Examples
#
# Requiring in packages
#
# ```coffee
# {EditorView} = require 'atom'
#
# miniEditorView = new EditorView(mini: true)
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
class EditorView extends View
  @configDefaults:
    fontFamily: ''
    fontSize: 16
    lineHeight: 1.3
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    normalizeIndentOnPaste: true
    nonWordCharacters: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
    preferredLineLength: 80
    tabLength: 2
    softWrap: false
    softTabs: true
    softWrapAtPreferredLineLength: false
    scrollSensitivity: 40
    useHardwareAcceleration: true
    confirmCheckoutHeadRevision: true
    invisibles:
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'

  @content: (params) ->
    attributes = params.attributes ? {}
    attributes.class = 'editor react editor-colors'
    attributes.tabIndex = -1
    @div attributes

  focusOnAttach: false

  # The constructor for setting up an `EditorView` instance.
  #
  # * `editorOrParams` Either an {Editor}, or an object with one property, `mini`.
  #    If `mini` is `true`, a "miniature" `Editor` is constructed.
  #    Typically, this is ideal for scenarios where you need an Atom editor,
  #    but without all the chrome, like scrollbars, gutter, _e.t.c._.
  #
  constructor: (editorOrParams, props) ->
    super

    if editorOrParams instanceof Editor
      @editor = editorOrParams
    else
      {@editor, mini, placeholderText} = editorOrParams
      props ?= {}
      props.mini = mini
      props.placeholderText = placeholderText
      @editor ?= new Editor
        buffer: new TextBuffer
        softWrapped: false
        tabLength: 2
        softTabs: true
        mini: mini

    props = defaults({@editor, parentView: this}, props)
    @component = React.renderComponent(EditorComponent(props), @element)

    node = @component.getDOMNode()

    @scrollView = $(node).find('.scroll-view')
    @underlayer = $(node).find('.highlights').addClass('underlayer')
    @overlayer = $(node).find('.lines').addClass('overlayer')
    @hiddenInput = $(node).find('.hidden-input')

    @subscribe atom.config.observe 'editor.showLineNumbers', =>
      @gutter = $(node).find('.gutter')

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

    @on 'focus', =>
      if @component?
        @component.onFocus()
      else
        @focusOnAttach = true

  # Public: Get the underlying editor model for this view.
  #
  # Returns an {Editor}
  getModel: -> @editor

  getEditor: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeightInPixels()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()
  Object.defineProperty @::, 'firstRenderedScreenRow', get: -> @component.getRenderedRowRange()[0]
  Object.defineProperty @::, 'lastRenderedScreenRow', get: -> @component.getRenderedRowRange()[1]
  Object.defineProperty @::, 'active', get: -> @is(@getPaneView()?.activeView)
  Object.defineProperty @::, 'isFocused', get: -> @component?.state.focused
  Object.defineProperty @::, 'mini', get: -> @component?.props.mini

  afterAttach: (onDom) ->
    return unless onDom
    return if @attached
    @attached = true
    @component.checkForVisibilityChange()

    @focus() if @focusOnAttach

    @addGrammarScopeAttribute()
    @subscribe @editor.onDidChangeGrammar => @addGrammarScopeAttribute()

    @trigger 'editor:attached', [this]

  addGrammarScopeAttribute: ->
    grammarScope = @editor.getGrammar()?.scopeName?.replace(/\./g, ' ')
    @attr('data-grammar', grammarScope)

  scrollTop: (scrollTop) ->
    if scrollTop?
      @editor.setScrollTop(scrollTop)
    else
      @editor.getScrollTop()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @editor.setScrollLeft(scrollLeft)
    else
      @editor.getScrollLeft()

  scrollToBottom: ->
    deprecate 'Use Editor::scrollToBottom instead. You can get the editor via editorView.getModel()'
    @editor.setScrollBottom(Infinity)

  scrollToScreenPosition: (screenPosition, options) ->
    deprecate 'Use Editor::scrollToScreenPosition instead. You can get the editor via editorView.getModel()'
    @editor.scrollToScreenPosition(screenPosition, options)

  scrollToBufferPosition: (bufferPosition, options) ->
    deprecate 'Use Editor::scrollToBufferPosition instead. You can get the editor via editorView.getModel()'
    @editor.scrollToBufferPosition(bufferPosition, options)

  scrollToCursorPosition: ->
    deprecate 'Use Editor::scrollToCursorPosition instead. You can get the editor via editorView.getModel()'
    @editor.scrollToCursorPosition()

  pixelPositionForBufferPosition: (bufferPosition) ->
    deprecate 'Use Editor::pixelPositionForBufferPosition instead. You can get the editor via editorView.getModel()'
    @editor.pixelPositionForBufferPosition(bufferPosition)

  pixelPositionForScreenPosition: (screenPosition) ->
    deprecate 'Use Editor::pixelPositionForScreenPosition instead. You can get the editor via editorView.getModel()'
    @editor.pixelPositionForScreenPosition(screenPosition)

  appendToLinesView: (view) ->
    view.css('position', 'absolute')
    view.css('z-index', 1)
    @find('.lines').prepend(view)

  detach: ->
    return unless @attached
    super
    @attached = false
    @unmountComponent()

  beforeRemove: ->
    return unless @attached
    @attached = false
    @unmountComponent()
    @editor.destroy()
    @trigger 'editor:detached', this

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

  # Public: Get this {EditorView}'s {PaneView}.
  #
  # Returns a {PaneView}
  getPaneView: ->
    @parent('.item-views').parents('.pane').view()
  getPane: ->
    deprecate 'Use EditorView::getPaneView() instead'
    @getPaneView()

  show: ->
    super
    @component?.checkForVisibilityChange()

  hide: ->
    super
    @component?.checkForVisibilityChange()

  pageDown: ->
    deprecate('Use editorView.getModel().pageDown()')
    @editor.pageDown()

  pageUp: ->
    deprecate('Use editorView.getModel().pageUp()')
    @editor.pageUp()

  getFirstVisibleScreenRow: ->
    deprecate 'Use Editor::getFirstVisibleScreenRow instead. You can get the editor via editorView.getModel()'
    @editor.getFirstVisibleScreenRow()

  getLastVisibleScreenRow: ->
    deprecate 'Use Editor::getLastVisibleScreenRow instead. You can get the editor via editorView.getModel()'
    @editor.getLastVisibleScreenRow()

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
    @component.getDOMNode().style.width = (@editor.getDefaultCharWidth() * widthInChars) + 'px'

  setShowIndentGuide: (showIndentGuide) ->
    deprecate 'This is going away. Use atom.config.set("editor.showIndentGuide", true|false) instead'
    @component.setShowIndentGuide(showIndentGuide)

  setSoftWrap: (softWrapped) ->
    deprecate 'Use Editor::setSoftWrapped instead. You can get the editor via editorView.getModel()'
    @editor.setSoftWrapped(softWrapped)

  setShowInvisibles: (showInvisibles) ->
    deprecate 'This is going away. Use atom.config.set("editor.showInvisibles", true|false) instead'
    @component.setShowInvisibles(showInvisibles)

  getText: ->
    @editor.getText()

  setText: (text) ->
    @editor.setText(text)

  insertText: (text) ->
    @editor.insertText(text)

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

  # Public: Set the text to appear in the editor when it is empty.
  #
  # This only affects mini editors.
  #
  # * `placeholderText` A {String} of text to display when empty.
  setPlaceholderText: (placeholderText) ->
    if @component?
      @component.setProps({placeholderText})
    else
      @props.placeholderText = placeholderText

  lineElementForScreenRow: (screenRow) ->
    $(@component.lineNodeForScreenRow(screenRow))
