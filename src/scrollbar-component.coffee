React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{extend, isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarComponent = React.createClass
  displayName: 'ScrollbarComponent'

  render: ->
    {orientation, className, scrollHeight, scrollWidth, visible} = @props
    {scrollableInOppositeDirection, horizontalScrollbarHeight, verticalScrollbarWidth} = @props
    {useHardwareAcceleration} = @props

    style = {}
    style.display = 'none' unless visible
    style.transform = 'translateZ(0)' if useHardwareAcceleration # See atom/atom#3559
    switch orientation
      when 'vertical'
        style.width = verticalScrollbarWidth
        style.bottom = horizontalScrollbarHeight if scrollableInOppositeDirection
      when 'horizontal'
        style.left = 0
        style.right = verticalScrollbarWidth if scrollableInOppositeDirection
        style.height = horizontalScrollbarHeight

    div {className, style},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: scrollWidth}

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

    @getDOMNode().addEventListener 'scroll', @onScroll

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'scroll', @onScroll

  shouldComponentUpdate: (newProps) ->
    return true if newProps.visible isnt @props.visible

    switch @props.orientation
      when 'vertical'
        not isEqualForProperties(newProps, @props, 'scrollHeight', 'scrollTop', 'scrollableInOppositeDirection', 'verticalScrollbarWidth')
      when 'horizontal'
        not isEqualForProperties(newProps, @props, 'scrollWidth', 'scrollLeft', 'scrollableInOppositeDirection', 'horizontalScrollbarHeight')

  componentDidUpdate: ->
    {orientation, scrollTop, scrollLeft} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        node.scrollTop = scrollTop
        @props.scrollTop = node.scrollTop # Ensure scrollTop reflects actual DOM without triggering another update
      when 'horizontal'
        node.scrollLeft = scrollLeft
        @props.scrollLeft = node.scrollLeft # Ensure scrollLeft reflects actual DOM without triggering another update

  onScroll: ->
    {orientation, onScroll} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        scrollTop = node.scrollTop
        @props.scrollTop = scrollTop # Ensure scrollTop reflects actual DOM without triggering another update
        onScroll(scrollTop)
      when 'horizontal'
        scrollLeft = node.scrollLeft
        @props.scrollLeft = scrollLeft # Ensure scrollLeft reflects actual DOM without triggering another update
        onScroll(scrollLeft)
