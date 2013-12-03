{View} = require 'space-pen'

module.exports =
class PaneView extends View
  @content: ->
    @div class: "pane", tabindex: -1, 'x-bind-focus': "focused", =>
      @div class: "active-item", => @div 'x-bind-component': "activeItem"

  created: ->
    @command 'pane:split-left', => @model.splitLeft(copyActiveItem: true)
    @command 'pane:split-right', => @model.splitRight(copyActiveItem: true)
    @command 'pane:split-up', => @model.splitUp(copyActiveItem: true)
    @command 'pane:split-down', => @model.splitDown(copyActiveItem: true)
