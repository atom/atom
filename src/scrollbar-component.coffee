React = require 'react'
{div} = require 'reactionary'

module.exports =
ScrollbarComponent = React.createClass
  render: ->
    {orientation, className, onScroll, scrollHeight, scrollWidth} = @props

    div {className, onScroll},
      switch orientation
        when 'vertical'
          div className: 'scrollbar-content', style: {height: scrollHeight}
        when 'horizontal'
          div className: 'scrollbar-content', style: {width: scrollWidth}
        else
          throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")
