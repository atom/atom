React = require 'react'
{div} = require 'reactionary'
{extend, isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarComponent = React.createClass
  render: ->
    {orientation, className, scrollHeight, scrollWidth, scrollableInOppositeDirection} = @props

    style = {}
    switch orientation
      when 'vertical'
        style.overflowX = 'hidden' unless scrollableInOppositeDirection
      when 'horizontal'
        style.overflowY = 'hidden' unless scrollableInOppositeDirection

    div {className, style, @onScroll},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: scrollWidth}

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

  shouldComponentUpdate: (newProps) ->
    switch @props.orientation
      when 'vertical'
        not isEqualForProperties(newProps, @props, 'scrollHeight', 'scrollTop', 'scrollableInOppositeDirection')
      when 'horizontal'
        not isEqualForProperties(newProps, @props, 'scrollWidth', 'scrollLeft', 'scrollableInOppositeDirection')

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
