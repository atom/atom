{View} = require 'space-pen'
React = require 'react'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'editor react-wrapper'

  constructor: (@editor) ->
    super

  getEditor: -> @editor

  afterAttach: (onDom) ->
    return unless onDom
    @attached = true
    @component = React.renderComponent(EditorComponent({@editor, parentView: this}), @element)
    @trigger 'editor:attached', [this]

  beforeDetach: ->
    React.unmountComponentAtNode(@element)
    @attached = false
    @trigger 'editor:detached', this

  getPane: ->
    @closest('.pane').view()
