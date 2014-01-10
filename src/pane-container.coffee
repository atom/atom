Serializable = require 'serializable'
Delegator = require 'delegato'
{$, View} = require './space-pen-extensions'
Pane = require './pane'
PaneContainerModel = require './pane-container-model'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainer extends View
  Serializable.includeInto(this)
  Delegator.includeInto(this)

  @deserialize: (state) ->
    new this(PaneContainerModel.deserialize(state.model))

  @content: ->
    @div class: 'panes'

  @delegatesMethods 'focusNextPane', 'focusPreviousPane', toProperty: 'model'

  initialize: (params) ->
    if params instanceof PaneContainerModel
      @model = params
    else
      @model = new PaneContainerModel({root: params?.root?.model})

    @subscribe @model.$root, 'value', @onRootChanged
    @subscribe @model, 'surrendered-focus', @onSurrenderedFocus

    @subscribe this, 'pane:attached', (event, pane) =>
      @triggerActiveItemChange() if @getActivePane() is pane

    @subscribe this, 'pane:removed', (event, pane) =>
      @triggerActiveItemChange() unless @getActivePane()?

    @subscribe this, 'pane:became-active', =>
      @triggerActiveItemChange()

    @subscribe this, 'pane:active-item-changed', (event, item) =>
      @triggerActiveItemChange() if @getActivePaneItem() is item

  viewForModel: (model) ->
    viewClass = model.getViewClass()
    model._view ?= new viewClass(model)

  triggerActiveItemChange: ->
    @trigger 'pane-container:active-pane-item-changed', [@getActivePaneItem()]

  serializeParams: ->
    model: @model.serialize()

  ### Public ###

  itemDestroyed: (item) ->
    @trigger 'item-destroyed', item

  getRoot: ->
    @children().first().view()

  setRoot: (root) ->
    @model.root = root?.model

  onRootChanged: (root) =>
    @children().detach()
    if root?
      view = @viewForModel(root)
      @append(view)
      view.makeActive?()

  onSurrenderedFocus: =>
    atom?.workspaceView?.focus()

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

  removeEmptyPanes: ->
    for pane in @getPanes() when pane.getItems().length == 0
      pane.remove()
