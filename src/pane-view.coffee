{View} = require 'television'

module.exports =
class PaneView extends View
  @content: ->
    @div class: "pane", tabindex: -1, 'x-bind-style-width-in-percent': "widthPercent", 'x-bind-style-height-in-percent': "heightPercent", =>
      @div class: "active-item", => @div 'x-bind-component': "activeItem"
