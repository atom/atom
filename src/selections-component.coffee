React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
SelectionComponent = require './selection-component'

module.exports =
SelectionsComponent = React.createClass
  displayName: 'SelectionsComponent'

  render: ->
    div className: 'selections', @renderSelections()

  renderSelections: ->
    {editor, lineHeight} = @props

    selectionComponents = []
    for selectionId, screenRange of @selectionRanges
      selectionComponents.push(SelectionComponent({key: selectionId, screenRange, editor, lineHeight}))
    selectionComponents

  componentWillMount: ->
    @selectionRanges = {}

  shouldComponentUpdate: ->
    {editor} = @props
    oldSelectionRanges = @selectionRanges
    newSelectionRanges = {}
    @selectionRanges = newSelectionRanges

    for selection, index in editor.getSelections()
      # Rendering artifacts occur on the lines GPU layer if we remove the last selection
      if index is 0 or (not selection.isEmpty() and editor.selectionIntersectsVisibleRowRange(selection))
        newSelectionRanges[selection.id] = selection.getScreenRange()

    for id, range of newSelectionRanges
      if oldSelectionRanges.hasOwnProperty(id)
        return true unless range.isEqual(oldSelectionRanges[id])
      else
        return true

    for id of oldSelectionRanges
      return true unless newSelectionRanges.hasOwnProperty(id)

    false
