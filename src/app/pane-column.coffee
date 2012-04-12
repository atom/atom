$ = require 'jquery'
{View} = require 'space-pen'
Pane = require 'pane'

module.exports =
class PaneColumn extends View
  @content: ->
    @div class: 'column'

  @deserialize: ({children}, rootView) ->
    childViews = children.map (child) -> rootView.deserializeView(child)
    new PaneColumn(childViews)

  initialize: (children=[]) ->
    @append(children...)

  serialize: ->
    viewClass: "PaneColumn"
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()