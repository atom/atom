{React, div} = require 'reactionary'
CursorComponent = require './cursor-component'

module.exports =
SelectionComponent = React.createClass
  render: ->
    console.log "render selection component"

    {selection, lineHeight, charWidth} = @props
    {cursor} = selection
    div className: 'selection',
      CursorComponent({cursor, lineHeight, charWidth})
