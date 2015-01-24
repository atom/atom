React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'

module.exports =
HighlightComponent = React.createClass
  displayName: 'HighlightComponent'
  lastFlashCount: 0
  lastFlashClass: null

  render: ->
    {editor, state} = @props

    className = 'highlight'
    className += " #{state.class}" if state.class?

    div {className},
      for region, i in state.regions
        regionClassName = 'region'
        regionClassName += " #{state.deprecatedRegionClass}" if state.deprecatedRegionClass?
        div className: regionClassName, key: i, style: region

  componentDidUpdate: ->
    if @props.state.flashCount > @lastFlashCount
      @startFlashAnimation()
      @lastFlashCount = @props.state.flashCount
      @lastFlashClass = @props.state.flashClass

  componentDidMount: ->
    {key} = @props
    presenter.onDidFlashHighlight @startFlashAnimation.bind(this)

  componentWillUnmount: ->
    @decorationDisposable?.dispose()
    @decorationDisposable = null

  startFlashAnimation: ->
    node = @getDOMNode()

    if @lastFlashClass?
      clearTimeout(@flashTimeoutId)
      node.classList.remove(@lastFlashClass)
      @lastFlashClass = null

    requestAnimationFrame =>
      flashClass = @props.state.flashClass
      node.classList.add(flashClass)
      removeFlashClass = -> node.classList.remove(flashClass)
      @flashTimeoutId = setTimeout(removeFlashClass, flash.duration)
