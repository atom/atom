React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
UnderlayerComponent = React.createClass
  displayName: 'UnderlayerComponent'

  render: ->
    if @isMounted()
      {scrollTop, scrollLeft, scrollHeight, scrollWidth} = @props
      style =
        height: scrollHeight
        width: scrollWidth
        WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    div {className: 'underlayer', style}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(@props, newProps, 'scrollTop', 'scrollLeft', 'scrollHeight', 'scrollWidth')
