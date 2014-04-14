React = require 'react'
{div} = require 'reactionary'

module.exports =
ScrollbarComponent = React.createClass
  lastScrollTop: null
  lastScrollLeft: null

  render: ->
    {orientation, className, onScroll, scrollHeight, scrollWidth} = @props

    div {className, onScroll},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: scrollWidth}

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

  componentDidUpdate: ->
    {orientation, scrollTop, scrollLeft} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        unless scrollTop is @lastScrollTop
          node.scrollTop = scrollTop
          @lastScrollTop = node.scrollTop
      when 'horizontal'
        unless scrollLeft is @lastScrollLeft
          node.scrollLeft = scrollLeft
          @lastScrollLeft = node.scrollLeft
