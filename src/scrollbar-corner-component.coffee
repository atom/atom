React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarCornerComponent = React.createClass
  displayName: 'ScrollbarCornerComponent'

  render: ->
    div className: 'scrollbar-corner',
      div ref: 'content'

  componentDidMount: ->
    @updateSync()

  componentDidUpdate: ->
    @updateSync()

  updateSync: ->
    {presenter} = @props

    @oldState ?= {}
    @newState ?= {}

    newHorizontalState = presenter.state.horizontalScrollbar
    newVerticalState = presenter.state.verticalScrollbar
    @newState.visible = newHorizontalState.visible and newVerticalState.visible
    @newState.height = newHorizontalState.height
    @newState.width = newVerticalState.width

    node = @getDOMNode()
    contentNode = @refs.content.getDOMNode()

    if @newState.visible isnt @oldState.visible
      if @newState.visible
        node.style.display = ''
      else
        node.style.display = 'none'
      @oldState.visible = @newState.visible

    if @newState.height isnt @oldState.height
      node.style.height = @newState.height + 'px'
      contentNode.style.height = @newState.height + 1 + 'px'
      @oldState.height = @newState.height

    if @newState.width isnt @oldState.width
      node.style.width = @newState.width + 'px'
      contentNode.style.width = @newState.width + 1 + 'px'
      @oldState.width = @newState.width
