Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', '&nbsp;'

  viewProperties:
    setPosition: (@_position) ->
      @css(@parentView.toPixelPosition(@_position))

    getPosition: ->
      @_position

