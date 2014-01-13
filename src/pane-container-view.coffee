Serializable = require 'serializable'
{$, View} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainerModel = require './pane-container-model'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @deserialize: (state) ->
    new this(PaneContainerModel.deserialize(state.model))

  @content: ->
    @div class: 'panes'

  initialize: (params) ->
    if params instanceof PaneContainerModel
      @model = params
    else
      @model = new PaneContainerModel({root: params?.root?.model})

    @subscribe @model.$root, @onRootChanged
    @subscribe @model.$activePaneItem.changes, @onActivePaneItemChanged

  viewForModel: (model) ->
    if model?
      viewClass = model.getViewClass()
      model._view ?= new viewClass(model)

  serializeParams: ->
    model: @model.serialize()

  ### Public ###

  itemDestroyed: (item) ->
    @trigger 'item-destroyed', [item]

  getRoot: ->
    @children().first().view()

  setRoot: (root) ->
    @model.root = root?.model

  onRootChanged: (root) =>
    focusedElement = document.activeElement if @hasFocus()

    oldRoot = @getRoot()
    if oldRoot instanceof PaneView and oldRoot.model.isDestroyed()
      @trigger 'pane:removed', [oldRoot]
    oldRoot?.detach()
    if root?
      view = @viewForModel(root)
      @append(view)
      focusedElement?.focus()
    else
      atom.workspaceView?.focus() if focusedElement?

  onActivePaneItemChanged: (activeItem) =>
    @trigger 'pane-container:active-pane-item-changed', [activeItem]

  removeChild: (child) ->
    throw new Error("Removing non-existant child") unless @getRoot() is child
    @setRoot(null)
    @trigger 'pane:removed', [child] if child instanceof PaneView

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
    @viewForModel(@model.activePane)

  getActivePaneItem: ->
    @model.activePaneItem

  getActiveView: ->
    @getActivePane()?.activeView

  paneForUri: (uri) ->
    for pane in @getPanes()
      view = pane.itemForUri(uri)
      return pane if view?
    null

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
