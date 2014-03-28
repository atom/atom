{View} = require 'space-pen'
{$$} = require 'space-pencil'
{React} = require 'reactionary'
EditorComponent = require './editor-component'

module.exports =
class ReactEditorView extends View
  @content: -> @div class: 'react-wrapper'

  constructor: (@editor) ->
    super

  afterAttach: (onDom) ->
    return unless onDom
    @component = React.renderComponent(EditorComponent({@editor}), @element)

  beforeDetach: ->
    React.unmountComponentAtNode(@element)
