React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    div className: 'highlights',
      @renderHighlights() if @props.performedInitialMeasurement

  renderHighlights: ->
    {editor, presenter} = @props
    highlightComponents = []
    for key, state of presenter.state.content.highlights
      highlightComponents.push(HighlightComponent({key, state}))
    highlightComponents

  componentDidMount: ->
    if atom.config.get('editor.useShadowDOM')
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.underlayer')
      @getDOMNode().appendChild(insertionPoint)
