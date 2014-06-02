React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual} = require 'underscore-plus'
SelectionComponent = require './selection-component'

module.exports =
SelectionsComponent = React.createClass
  displayName: 'SelectionsComponent'

  render: ->
    div className: 'selections', @renderSelections()

  renderSelections: ->
    {editor, selectionScreenRanges, lineHeightInPixels} = @props

    selectionComponents = []
    for selectionId, screenRange of selectionScreenRanges
      selectionComponents.push(SelectionComponent({key: selectionId, screenRange, editor, lineHeightInPixels}))
    selectionComponents

  componentWillMount: ->
    @selectionRanges = {}

  shouldComponentUpdate: (newProps) ->
    not isEqual(newProps.selectionScreenRanges, @props.selectionScreenRanges)
