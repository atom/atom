{View} = require 'space-pen'
Pane = require 'pane'
$ = require 'jquery'

module.exports =
class PaneContainer extends View
  registerDeserializer(this)

  @deserialize: ({root}) ->
    container = new PaneContainer
    container.append(deserialize(root)) if root
    container.removeEmptyPanes()
    container

  @content: ->
    @div id: 'panes'

  initialize: ->
    @destroyedItemStates = []

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

  reopenItem: ->
    if lastItemState = @destroyedItemStates.pop()
      if activePane = @getActivePane()
        activePane.showItem(deserialize(lastItemState))
        true
      else
        @append(new Pane(deserialize(lastItemState)))

  itemDestroyed: (item) ->
    state = item.serialize?()
    state.uri ?= item.getUri?()
    @destroyedItemStates.push(state) if state?

  itemAdded: (item) ->
    itemUri = item.getUri?()
    @destroyedItemStates = @destroyedItemStates.filter (itemState) ->
      itemState.uri isnt itemUri

  getRoot: ->
    @children().first().view()

  saveAll: ->
    pane.saveItems() for pane in @getPanes()

  getPanes: ->
    @find('.pane').views()

  indexOfPane: (pane) ->
    @getPanes().indexOf(pane.view())

  paneAtIndex: (index) ->
    @getPanes()[index]

  eachPane: (callback) ->
    callback(pane) for pane in @getPanes()
    paneAttached = (e) -> callback($(e.target).view())
    @on 'pane:attached', paneAttached
    cancel: => @off 'pane:attached', paneAttached

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  getActivePaneItem: ->
    @getActivePane()?.activeItem

  getActiveView: ->
    @getActivePane()?.activeView

  adjustPaneDimensions: ->
    if root = @getRoot()
      root.css(width: '100%', height: '100%', top: 0, left: 0)
      root.adjustDimensions()

  removeEmptyPanes: ->
    for pane in @getPanes() when pane.getItems().length == 0
      pane.remove()

  afterAttach: ->
    @adjustPaneDimensions()
