{React, div} = require 'reactionary'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'

module.exports =
SelectionComponent = React.createClass
  mixins: [SubscriberMixin]

  render: ->
    div className: 'selection',
      CursorComponent(cursor: @props.selection.cursor)

  componentDidMount: ->
    @subscribe @props.selection, 'screen-range-changed', => @forceUpdate()

  componentWillUnmount: ->
    @unsubscribe()
