{last, isEqual} = require 'underscore-plus'
React = require 'react-atom-fork'
{input} = require 'reactionary-atom-fork'

module.exports =
InputComponent = React.createClass
  displayName: 'InputComponent'

  render: ->
    {className} = @props
    input {className}

  getInitialState: ->
    {lastChar: ''}

  componentDidMount: ->
    node = @getDOMNode()
    node.addEventListener 'paste', @onPaste
    node.addEventListener 'compositionupdate', @onCompositionUpdate
    node.setAttribute('data-react-skip-selection-restoration', true)
    node.style['-webkit-transform'] = 'translateZ(0)'

  componentDidUpdate: ->
    node = @getDOMNode()
    @oldState ?= {}
    newState = @props.presenter.state.hiddenInput

    if newState.top isnt @oldState.top
      node.style.top = newState.top + 'px'
      @oldState.top = newState.top

    if newState.left isnt @oldState.left
      node.style.left = newState.left + 'px'
      @oldState.left = newState.left

    if newState.width isnt @oldState.width
      node.style.width = newState.width + 'px'
      @oldState.width = newState.width

    if newState.height isnt @oldState.height
      node.style.height = newState.height + 'px'
      @oldState.height = newState.height

    # Don't let text accumulate in the input forever, but avoid excessive reflows
    if @lastValueLength > 500 and not @isPressAndHoldCharacter(@state.lastChar)
      node.value = ''
      @lastValueLength = 0

  # This should actually consult the property lists in /System/Library/Input Methods/PressAndHold.app
  isPressAndHoldCharacter: (char) ->
    @state.lastChar.match /[aeiouAEIOU]/

  onPaste: (e) ->
    e.preventDefault()

  focus: ->
    @getDOMNode().focus()
