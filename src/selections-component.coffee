React = require 'react'
{div} = require 'reactionary'
SelectionComponent = require './selection-component'

module.exports =
SelectionsComponent = React.createClass
  displayName: 'SelectionsComponent'

  render: ->
    {editor, lineHeight} = @props

    div className: 'selections',
      if @isMounted()
        for selection, index in editor.getSelections()
          # Rendering artifacts occur on the lines GPU layer if we remove the last selection
          if index is 0 or (not selection.isEmpty() and editor.selectionIntersectsVisibleRowRange(selection))
            SelectionComponent({key: selection.id, selection, editor, lineHeight})
