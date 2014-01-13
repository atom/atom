{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
PaneAxisView = require './pane-axis-view'

### Internal ###

module.exports =
class PaneRowView extends PaneAxisView
  @content: ->
    @div class: 'pane-row'

  className: ->
    "PaneRow"
