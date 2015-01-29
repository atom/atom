React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{extend, isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarComponent = React.createClass
  displayName: 'ScrollbarComponent'

  render: ->
    {presenter, orientation, className, useHardwareAcceleration} = @props

    switch orientation
      when 'vertical'
        state = presenter.state.verticalScrollbar
      when 'horizontal'
        state = presenter.state.horizontalScrollbar

    style = {}

    style.display = 'none' unless state.visible
    style.transform = 'translateZ(0)' if useHardwareAcceleration # See atom/atom#3559
    switch orientation
      when 'vertical'
        style.width = state.width
        style.bottom = state.bottom
      when 'horizontal'
        style.left = 0
        style.right = state.right
        style.height = state.height

    div {className, style},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: presenter.state.scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: presenter.state.content.scrollWidth}

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

    @getDOMNode().addEventListener 'scroll', @onScroll

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'scroll', @onScroll

  componentDidUpdate: ->
    {orientation, presenter} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        node.scrollTop = presenter.state.scrollTop
      when 'horizontal'
        node.scrollLeft = presenter.state.content.scrollLeft

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
