{last, isEqual} = require 'underscore-plus'
React = require 'react-atom-fork'
{input} = require 'reactionary-atom-fork'

module.exports =
InputComponent = React.createClass
  displayName: 'InputComponent'

  render: ->
    {className, style, onFocus, onBlur} = @props

    input {className, style, onFocus, onBlur, 'data-react-skip-selection-restoration': true}

  getInitialState: ->
    {lastChar: ''}

  componentDidMount: ->
    @getDOMNode().addEventListener 'paste', @onPaste
    @getDOMNode().addEventListener 'compositionupdate', @onCompositionUpdate

  # Don't let text accumulate in the input forever, but avoid excessive reflows
  componentDidUpdate: ->
    if @lastValueLength > 500 and not @isPressAndHoldCharacter(@state.lastChar)
      @getDOMNode().value = ''
      @lastValueLength = 0

  # This should actually consult the property lists in /System/Library/Input Methods/PressAndHold.app
  isPressAndHoldCharacter: (char) ->
    @state.lastChar.match /[aeiouAEIOU]/

  shouldComponentUpdate: (newProps) ->
    not isEqual(newProps.style, @props.style)

  onPaste: (e) ->
    e.preventDefault()

  onFocus: ->
    @props.onFocus?()

  onBlur: ->
    @props.onBlur?()

  focus: ->
    @getDOMNode().focus()
