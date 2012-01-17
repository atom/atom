Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', '&nbsp;'

  viewProperties:
    setPosition: (@position) ->
      @css(@parentView.toPixelPosition(position))

    getPosition: ->
      @position

