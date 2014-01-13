{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
PaneAxisView = require './pane-axis-view'

# Internal:
module.exports =
class PaneColumnView extends PaneAxisView

  @content: ->
    @div class: 'pane-column'

  className: ->
    "PaneColumn"
