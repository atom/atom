React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{debounce, toArray, isEqualForProperties, isEqual} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'
CursorComponent = require './cursor-component'

module.exports =
CursorsComponent = React.createClass
  displayName: 'CursorsComponent'

  render: ->
    {presenter} = @props

    className = 'cursors'
    className += ' blink-off' if presenter.state.content.blinkCursorsOff

    div {className},
      if presenter.hasRequiredMeasurements()
        for key, pixelRect of presenter.state.content.cursors
          CursorComponent({key, pixelRect})
