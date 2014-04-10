{View, $} = require 'space-pen'
React = require 'react'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'editor react-wrapper'

  constructor: (@editor) ->
    super

  getEditor: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeight()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()

  afterAttach: (onDom) ->
    return unless onDom
    @attached = true
    @component = React.renderComponent(EditorComponent({@editor, parentView: this}), @element)
    @underlayer = $(@component.getDOMNode()).find('.underlayer')
    @trigger 'editor:attached', [this]

  pixelPositionForBufferPosition: (bufferPosition) ->
    @editor.pixelPositionForBufferPosition(bufferPosition)

  beforeDetach: ->
    React.unmountComponentAtNode(@element)
    @attached = false
    @trigger 'editor:detached', this

  getPane: ->
    @closest('.pane').view()
