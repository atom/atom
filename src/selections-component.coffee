React = require 'react'
{div} = require 'reactionary'
SelectionComponent = require './selection-component'

module.exports =
SelectionsComponent = React.createClass
  displayName: 'SelectionsComponent'

  render: ->
    {editor} = @props

    div className: 'selections',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        SelectionComponent({selection})
