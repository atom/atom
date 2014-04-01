punycode = require 'punycode'
{last} = require 'underscore-plus'
{React, input} = require 'reactionary'

module.exports =
InputComponent = React.createClass
  render: ->
    input className: @props.className, ref: 'input'

  getInitialState: ->
    {lastChar: ''}

  componentDidMount: ->
    @getDOMNode().addEventListener 'input', @onInput
    @getDOMNode().addEventListener 'compositionupdate', @onCompositionUpdate

  # Don't let text accumulate in the input forever, but avoid excessive reflows
  componentDidUpdate: ->
    if @lastValueLength > 500 and not @isPressAndHoldCharacter(@state.lastChar)
      @getDOMNode().value = ''
      @lastValueLength = 0

  # This should actually consult the property lists in /System/Library/Input Methods/PressAndHold.app
  isPressAndHoldCharacter: (char) ->
    @state.lastChar.match /[aeiouAEIOU]/

  shouldComponentUpdate: -> false

  onInput: (e) ->
    valueCharCodes = punycode.ucs2.decode(@getDOMNode().value)
    valueLength = valueCharCodes.length
    replaceLastChar = valueLength is @lastValueLength
    @lastValueLength = valueLength
    lastChar = String.fromCharCode(last(valueCharCodes))
    @props.onInput?(lastChar, replaceLastChar)

  focus: ->
    @getDOMNode().focus()
