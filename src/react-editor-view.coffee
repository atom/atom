{View} = require 'space-pen'
React = require 'react'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'react-wrapper'

  constructor: (@editor) ->
    super

  getEditor: -> @editor

  afterAttach: (onDom) ->
    return unless onDom
    @attached = true
    @component = React.renderComponent(EditorComponent({@editor}), @element)
    @trigger 'editor:attached', [this]

  beforeDetach: ->
    React.unmountComponentAtNode(@element)
    @attached = false
    @trigger 'editor:detached', this
