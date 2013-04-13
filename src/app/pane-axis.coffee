$ = require 'jquery'
{View} = require 'space-pen'

module.exports =
class PaneAxis extends View
  # Internal:
  @deserialize: ({children}) ->
    childViews = children.map (child) -> deserialize(child)
    new this(childViews)

  # Internal:
  initialize: (children=[]) ->
    @append(children...)
  # Internal:
  serialize: ->
    deserializer: @className()
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()

  horizontalChildUnits: ->
    $(child).view().horizontalGridUnits() for child in @children()

  verticalChildUnits: ->
    $(child).view().verticalGridUnits() for child in @children()
