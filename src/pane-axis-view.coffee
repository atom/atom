{View} = require 'television'

module.exports =
class PaneAxisView extends View
  @content: ->
    @div 'class': "axis {{orientation}}", 'x-bind-collection': "children"
