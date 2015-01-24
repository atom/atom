React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
HighlightComponent = React.createClass
  displayName: 'HighlightComponent'
  currentFlashCount: 0
  currentFlashClass: null

  render: ->
    {state} = @props

    className = 'highlight'
    className += " #{state.class}" if state.class?

    div {className},
      for region, i in state.regions
        regionClassName = 'region'
        regionClassName += " #{state.deprecatedRegionClass}" if state.deprecatedRegionClass?
        div className: regionClassName, key: i, style: region

  componentDidMount: ->
    @flashIfRequested()

  componentDidUpdate: ->
    @flashIfRequested()

  flashIfRequested: ->
    if @props.state.flashCount > @currentFlashCount
      @currentFlashCount = @props.state.flashCount

      node = @getDOMNode()
      {flashClass, flashDuration} = @props.state

      addFlashClass = =>
        node.classList.add(flashClass)
        @currentFlashClass = flashClass
        @flashTimeoutId = setTimeout(removeFlashClass, flashDuration)

      removeFlashClass = =>
        node.classList.remove(@currentFlashClass)
        @currentFlashClass = null
        clearTimeout(@flashTimeoutId)

      if @currentFlashClass?
        removeFlashClass()
        requestAnimationFrame(addFlashClass)
      else
        addFlashClass()
