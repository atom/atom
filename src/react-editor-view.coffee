{View, $} = require 'space-pen'
React = require 'react-atom-fork'
EditorComponent = require './editor-component'
{defaults} = require 'underscore-plus'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'editor react-wrapper'

  focusOnAttach: false

  constructor: (@editor, @props) ->
    super

  getEditor: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeightInPixels()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()
  Object.defineProperty @::, 'firstRenderedScreenRow', get: -> @component.getRenderedRowRange()[0]
  Object.defineProperty @::, 'lastRenderedScreenRow', get: -> @component.getRenderedRowRange()[1]
  Object.defineProperty @::, 'active', get: -> @is(@getPane().activeView)

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

  scrollToScreenPosition: (screenPosition) ->
    @editor.scrollToScreenPosition(screenPosition)

  scrollToBufferPosition: (bufferPosition) ->
    @editor.scrollToBufferPosition(bufferPosition)

  afterAttach: (onDom) ->
    return unless onDom
    @attached = true
    props = defaults({@editor, parentView: this}, @props)
    @component = React.renderComponent(EditorComponent(props), @element)

    node = @component.getDOMNode()

    @underlayer = $(node).find('.selections').addClass('underlayer')
    @overlayer = $(node).find('.lines').addClass('overlayer')

    @gutter = $(node).find('.gutter')
    @gutter.removeClassFromAllLines = (klass) =>
      @gutter.find('.line-number').removeClass(klass)

    @gutter.getLineNumberElement = (bufferRow) =>
      @gutter.find("[data-buffer-row='#{bufferRow}']")

    @gutter.addClassToLine = (bufferRow, klass) =>
      lines = @gutter.find("[data-buffer-row='#{bufferRow}']")
      lines.addClass(klass)
      lines.length > 0

    @focus() if @focusOnAttach

    @trigger 'editor:attached', [this]

  pixelPositionForBufferPosition: (bufferPosition) ->
    @editor.pixelPositionForBufferPosition(bufferPosition)

  pixelPositionForScreenPosition: (screenPosition) ->
    @editor.pixelPositionForScreenPosition(screenPosition)

  appendToLinesView: (view) ->
    view.css('position', 'absolute')
    view.css('z-index', 1)
    @find('.lines').prepend(view)

  beforeRemove: ->
    React.unmountComponentAtNode(@element)
    @attached = false
    @trigger 'editor:detached', this

  # Public: Split the editor view left.
  splitLeft: ->
    pane = @getPane()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  # Public: Split the editor view right.
  splitRight: ->
    pane = @getPane()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  # Public: Split the editor view up.
  splitUp: ->
    pane = @getPane()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  # Public: Split the editor view down.
  splitDown: ->
    pane = @getPane()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  getPane: ->
    @closest('.pane').view()

  focus: ->
    if @component?
      @component.onFocus()
    else
      @focusOnAttach = true

  hide: ->
    super
    @component?.hide()

  show: ->
    super
    @component?.show()

  getModel: ->
    @component?.getModel()

  getFirstVisibleScreenRow: ->
    @editor.getVisibleRowRange()[0]

  getLastVisibleScreenRow: ->
    @editor.getVisibleRowRange()[1]

  requestDisplayUpdate: -> # No-op shim for find-and-replace
