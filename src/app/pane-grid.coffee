$ = require 'jquery'
{View} = require 'space-pen'

module.exports =
class PaneGrid extends View
  @deserialize: ({children}) ->
    childViews = children.map (child) -> deserializeView(child)
    new this(childViews)

  initialize: (children=[]) ->
    @append(children...)

  serialize: ->
    viewClass: @className()
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()

  horizontalChildUnits: ->
    $(child).view().horizontalGridUnits() for child in @children()

  verticalChildUnits: ->
    $(child).view().verticalGridUnits() for child in @children()
