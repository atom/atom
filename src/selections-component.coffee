React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
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
    not isEqualForProperties(newProps, @props, 'selectionScreenRanges', 'lineHeightInPixels', 'defaultCharWidth')
