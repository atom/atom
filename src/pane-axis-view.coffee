{View} = require 'television'

module.exports =
class PaneAxisView extends View
  @content: ->
    @div 'x-bind-attribute-class': "orientation", 'x-bind-collection': "children"
