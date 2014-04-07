React = require 'react'
{div} = require 'reactionary'
SubscriberMixin = require './subscriber-mixin'

module.exports =
CursorComponent = React.createClass
  mixins: [SubscriberMixin]

  render: ->
    {top, left, height, width} = @props.cursor.getPixelRect()
    className = 'cursor'
    className += ' blink-off' if @props.blinkOff

    div className: className, style: {top, left, height, width}

  componentDidMount: ->
    @subscribe @props.cursor, 'moved', => @forceUpdate()

  componentWillUnmount: ->
    @unsubscribe()
