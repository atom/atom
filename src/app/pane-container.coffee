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
    if panes.length > 1
      currentIndex = panes.indexOf(@getFocusedPane())
      nextIndex = (currentIndex + 1) % panes.length
      panes[nextIndex].focus()
      true
    else
      false

  makeNextPaneActive: ->
    panes = @getPanes()
    currentIndex = panes.indexOf(@getActivePane())
    nextIndex = (currentIndex + 1) % panes.length
    panes[nextIndex].makeActive()

  getRoot: ->
    @children().first().view()

  getPanes: ->
    @find('.pane').toArray().map (node)-> $(node).view()

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  getActivePaneItem: ->
    @getActivePane()?.currentItem

  getActiveView: ->
    @getActivePane()?.currentView

  adjustPaneDimensions: ->
    if root = @getRoot()
      root.css(width: '100%', height: '100%', top: 0, left: 0)
      root.adjustDimensions()

  afterAttach: ->
    @adjustPaneDimensions()
