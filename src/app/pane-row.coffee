$ = require 'jquery'
{View} = require 'space-pen'
Pane = require 'pane'

module.exports =
class PaneRow extends View
  @content: ->
    @div class: 'row'

  @deserialize: ({children}, rootView) ->
    childViews = children.map (child) -> rootView.deserializeView(child)
    new PaneRow(childViews)

  initialize: (children=[]) ->
    @append(children...)

  serialize: ->
    viewClass: "PaneRow"
    children: @childViewStates()

  childViewStates: ->
    $(child).view().serialize() for child in @children()