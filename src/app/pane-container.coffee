{View} = require 'space-pen'
$ = require 'jquery'

module.exports =
class PaneContainer extends View
  registerDeserializer(this)

  @deserialize: ({root}) ->
    container = new PaneContainer
    container.append(deserialize(root)) if root
    container

  @content: ->
    @div id: 'panes'

  serialize: ->
    deserializer: 'PaneContainer'
    root: @getRoot()?.serialize()

  focusNextPane: ->
    panes = @getPanes()
    currentIndex = panes.indexOf(@getFocusedPane())
    nextIndex = (currentIndex + 1) % panes.length
    panes[nextIndex].focus()

  getRoot: ->
    @children().first().view()

  getPanes: ->
    @find('.pane').toArray().map (node)-> $(node).view()

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  adjustPaneDimensions: ->
    if root = @getRoot()
      root.css(width: '100%', height: '100%', top: 0, left: 0)
      root.adjustDimensions()

  afterAttach: ->
    @adjustPaneDimensions()
