Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', '&nbsp;'

  viewProperties:
    setPosition: (@_position) ->
      @updateAbsolutePosition()

    getPosition: ->
      @_position

    updateAbsolutePosition: ->
      position = @parentView.toPixelPosition(@_position)
      @css(position)

