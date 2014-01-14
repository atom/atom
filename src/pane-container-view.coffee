Delegator = require 'delegato'
{$, View} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainer = require './pane-container'

# Private: Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  Delegator.includeInto(this)
  atom.views.register(require './pane-axis-view')
  atom.views.register(require './pane-view')

  @delegatesMethod 'saveAll', toProperty: 'model'

  @content: ->
    @div class: 'panes'

  initialize: (params) ->
    if params instanceof PaneContainer
      @model = params
    else
      @model = new PaneContainer({root: params?.root?.model})

    @subscribe @model.$root, @onRootChanged
    @subscribe @model.$activePaneItem.changes, @onActivePaneItemChanged

  ### Public ###

  getRoot: ->
    @children().first().view()

  setRoot: (root) ->
    atom.views.associate(root.model, root) if root?
    @model.root = root?.model

  onRootChanged: (root) =>
    focusedElement = document.activeElement if @hasFocus()

    oldRoot = @getRoot()
    if oldRoot instanceof PaneView and oldRoot.model.isDestroyed()
      @trigger 'pane:removed', [oldRoot]
    oldRoot?.detach()
    if root?
      view = atom.views.findOrCreate(root)
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
    atom.views.findOrCreate(@model.activePane)

  getActivePaneItem: ->
    @model.activePaneItem

  getActiveView: ->
    @getActivePane()?.activeView

  paneForUri: (uri) ->
    atom.views.findOrCreate(@model.paneForUri(uri))

  focusNextPane: ->
    @model.activateNextPane()

  focusPreviousPane: ->
    @model.activatePreviousPane()
