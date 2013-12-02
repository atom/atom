{View} = require 'space-pen'

module.exports =
class PaneView extends View
  @content: ->
    @div class: "pane", tabindex: -1, 'x-bind-focus': "focused", =>
      @div class: "active-item", => @div 'x-bind-component': "activeItem"

  created: ->
    @command 'pane:split-left', => @splitLeft(@copyActiveItem())
    @command 'pane:split-right', => @splitRight(@copyActiveItem())
    @command 'pane:split-up', => @splitUp(@copyActiveItem())
    @command 'pane:split-down', => @splitDown(@copyActiveItem())
