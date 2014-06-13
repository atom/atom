React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    div className: 'highlights', @renderSelections()

  renderSelections: ->
    {editor, selectionScreenRanges, lineHeightInPixels} = @props

    selectionComponents = []
    for selectionId, screenRange of selectionScreenRanges
      selectionComponents.push(HighlightComponent({key: selectionId, screenRange, editor, lineHeightInPixels}))
    selectionComponents

  componentWillMount: ->
    @selectionRanges = {}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'selectionScreenRanges', 'lineHeightInPixels', 'defaultCharWidth')
