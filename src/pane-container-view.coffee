{View} = require 'television'
PaneAxisView = require './pane-axis-view'
PaneView = require './pane-view'

module.exports =
class PaneContainerView extends View
  @register PaneAxisView, PaneView

  @content: ->
    @div class: 'panes', => @div 'x-bind-component': "root"
