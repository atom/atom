{React, div} = require 'reactionary'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'

module.exports =
SelectionComponent = React.createClass
  mixins: [SubscriberMixin]

  render: ->
    {selection, lineHeight, charWidth} = @props
    {cursor} = selection
    div className: 'selection',
      CursorComponent({cursor, lineHeight, charWidth})

  componentDidMount: ->
    @subscribe @props.selection, 'screen-range-changed', => @forceUpdate()

  componentWillUnmount: ->
    @unsubscribe()
