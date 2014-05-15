{View, $} = require 'space-pen'
React = require 'react'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'editor react-wrapper'

  focusOnAttach: false

  constructor: (@editor) ->
    super

  getEditor: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeight()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()

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
    @component = React.renderComponent(EditorComponent({@editor, parentView: this}), @element)

    node = @component.getDOMNode()

    @underlayer = $(node).find('.selections')

    @gutter = $(node).find('.gutter')
    @gutter.removeClassFromAllLines = (klass) =>
      @gutter.find('.line-number').removeClass(klass)

    @gutter.addClassToLine = (bufferRow, klass) =>
      lines = @gutter.find(".line-number-#{bufferRow}")
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
    @find('.scroll-view-content').prepend(view)

  beforeRemove: ->
    React.unmountComponentAtNode(@element)
    @attached = false
    @trigger 'editor:detached', this

  getPane: ->
    @closest('.pane').view()

  focus: ->
    if @component?
      @component.onFocus()
    else
      @focusOnAttach = true
