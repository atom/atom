punycode = require 'punycode'
{last, isEqual} = require 'underscore-plus'
React = require 'react'
{input} = require 'reactionary'

module.exports =
InputComponent = React.createClass
  displayName: 'InputComponent'

  render: ->
    {className, style, onFocus, onBlur} = @props

    input {className, style, onFocus, onBlur}

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

  shouldComponentUpdate: (newProps) ->
    not isEqual(newProps.style, @props.style)

  onInput: (e) ->
    e.stopPropagation()
    valueCharCodes = punycode.ucs2.decode(@getDOMNode().value)
    valueLength = valueCharCodes.length
    replaceLastChar = valueLength is @lastValueLength
    @lastValueLength = valueLength
    lastChar = String.fromCharCode(last(valueCharCodes))
    @props.onInput?(lastChar, replaceLastChar)

  onFocus: ->
    @props.onFocus?()

  onBlur: ->
    @props.onBlur?()

  focus: ->
    @getDOMNode().focus()
