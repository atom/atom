React = require 'react'
{div} = require 'reactionary'
SelectionComponent = require './selection-component'

module.exports =
SelectionsComponent = React.createClass
  displayName: 'SelectionsComponent'

  render: ->
    {editor} = @props

    div className: 'selections',
      for selection in editor.getSelections()
        if not selection.isEmpty() and editor.selectionIntersectsVisibleRowRange(selection)
          SelectionComponent({key: selection.id, selection})
