Serializable = require 'serializable'
{$, View} = require './space-pen-extensions'
Pane = require './pane'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainer extends View
  Serializable.includeInto(this)
  atom.deserializers.add(this)

  @content: ->
    @div class: 'panes'

  initialize: ({root}={}) ->
    @setRoot(root)

    @subscribe this, 'pane:attached', (event, pane) =>
      @triggerActiveItemChange() if @getActivePane() is pane

    @subscribe this, 'pane:removed', (event, pane) =>
      @triggerActiveItemChange() unless @getActivePane()?

    @subscribe this, 'pane:became-active', =>
      @triggerActiveItemChange()

    @subscribe this, 'pane:active-item-changed', (event, item) =>
      @triggerActiveItemChange() if @getActivePaneItem() is item

  triggerActiveItemChange: ->
    @trigger 'pane-container:active-pane-item-changed', [@getActivePaneItem()]

  serializeParams: ->
    root: @getRoot()?.serialize()

  deserializeParams: (params) ->
    params.root = atom.deserializers.deserialize(params.root)
    params

  ### Public ###

  focusNextPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@getFocusedPane())
      nextIndex = (currentIndex + 1) % panes.length
      panes[nextIndex].focus()
      true
    else
      false

  focusPreviousPane: ->
    panes = @getPanes()
    if panes.length > 1
      currentIndex = panes.indexOf(@getFocusedPane())
      previousIndex = currentIndex - 1
      previousIndex = panes.length - 1 if previousIndex < 0
      panes[previousIndex].focus()
      true
    else
      false

  makeNextPaneActive: ->
    panes = @getPanes()
    currentIndex = panes.indexOf(@getActivePane())
    nextIndex = (currentIndex + 1) % panes.length
    panes[nextIndex].makeActive()

  itemDestroyed: (item) ->
    @trigger 'item-destroyed', item

  getRoot: ->
    @children().first().view()

  setRoot: (root, {suppressPaneItemChangeEvents}={}) ->
    @empty()
    if root?
      @append(root)
      root.makeActive?()

  removeChild: (child) ->
    throw new Error("Removing non-existant child") unless @getRoot() is child
    @setRoot(null)
    @trigger 'pane:removed', [child] if child instanceof Pane

  saveAll: ->
    pane.saveItems() for pane in @getPanes()

  confirmClose: ->
    saved = true
    for pane in @getPanes()
      for item in pane.getItems()
        if not pane.promptToSaveItem(item)
          saved = false
          break
    saved

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
    off: => @off 'pane:attached', paneAttached

  getFocusedPane: ->
    @find('.pane:has(:focus)').view()

  getActivePane: ->
    @find('.pane.active').view() ? @find('.pane:first').view()

  getActivePaneItem: ->
    @getActivePane()?.activeItem

  getActiveView: ->
    @getActivePane()?.activeView

  paneForUri: (uri) ->
    for pane in @getPanes()
      view = pane.itemForUri(uri)
      return pane if view?
    null

  adjustPaneDimensions: ->
    if root = @getRoot()
      root.css(width: '100%', height: '100%', top: 0, left: 0)
      root.adjustDimensions()

  removeEmptyPanes: ->
    for pane in @getPanes() when pane.getItems().length == 0
      pane.remove()

  afterAttach: ->
    @adjustPaneDimensions()
