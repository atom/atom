{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
PaneAxis = require './pane-axis'

# Internal:
module.exports =
class PaneColumn extends PaneAxis

  @content: ->
    @div class: 'column'

  className: ->
    "PaneColumn"
