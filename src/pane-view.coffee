{View} = require 'television'

module.exports =
class PaneView extends View
  @content: ->
    @div class: "pane", tabindex: -1, =>
      @div class: "active-item", => @div 'x-bind-component': "activeItem"
