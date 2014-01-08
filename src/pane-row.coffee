{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
PaneAxis = require './pane-axis'

### Internal ###

module.exports =
class PaneRow extends PaneAxis
  @content: ->
    @div class: 'row'

  className: ->
    "PaneRow"
