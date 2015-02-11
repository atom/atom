{last, isEqual} = require 'underscore-plus'
React = require 'react-atom-fork'
{input} = require 'reactionary-atom-fork'

module.exports =
InputComponent = React.createClass
  displayName: 'InputComponent'

  render: ->
    {className} = @props
    style = @props.presenter.state.hiddenInput
    style.WebkitTransform ?= 'translateZ(0)'
    input {className, style, 'data-react-skip-selection-restoration': true}

  getInitialState: ->
    {lastChar: ''}

  componentDidMount: ->
    node = @getDOMNode()
    node.addEventListener 'paste', @onPaste
    node.addEventListener 'compositionupdate', @onCompositionUpdate

  # Don't let text accumulate in the input forever, but avoid excessive reflows
  componentDidUpdate: ->
    if @lastValueLength > 500 and not @isPressAndHoldCharacter(@state.lastChar)
      @getDOMNode().value = ''
      @lastValueLength = 0

  # This should actually consult the property lists in /System/Library/Input Methods/PressAndHold.app
  isPressAndHoldCharacter: (char) ->
    @state.lastChar.match /[aeiouAEIOU]/

  onPaste: (e) ->
    e.preventDefault()

  focus: ->
    @getDOMNode().focus()
