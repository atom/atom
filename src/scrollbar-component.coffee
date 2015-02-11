React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{extend, isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarComponent = React.createClass
  displayName: 'ScrollbarComponent'

  render: ->
    {presenter, orientation, className} = @props

    switch orientation
      when 'vertical'
        @newState = presenter.state.verticalScrollbar
      when 'horizontal'
        @newState = presenter.state.horizontalScrollbar

    style = {}

    style.display = 'none' unless @newState.visible
    style.transform = 'translateZ(0)' # See atom/atom#3559
    switch orientation
      when 'vertical'
        style.width = @newState.width
        style.bottom = @newState.bottom
      when 'horizontal'
        style.left = 0
        style.right = @newState.right
        style.height = @newState.height

    div {className, style},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: @newState.scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: @newState.scrollWidth}

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

    @getDOMNode().addEventListener 'scroll', @onScroll

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'scroll', @onScroll

  componentDidUpdate: ->
    {orientation} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        node.scrollTop = @newState.scrollTop
      when 'horizontal'
        node.scrollLeft = @newState.scrollLeft

  onScroll: ->
    {orientation, onScroll} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        scrollTop = node.scrollTop
        onScroll(scrollTop)
      when 'horizontal'
        scrollLeft = node.scrollLeft
        onScroll(scrollLeft)
