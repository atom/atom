{deprecate} = require 'grim'
Delegator = require 'delegato'
{CompositeDisposable} = require 'event-kit'
{$, View, callAttachHooks} = require './space-pen-extensions'
PaneView = require './pane-view'
PaneContainer = require './pane-container'

# Manages the list of panes within a {WorkspaceView}
module.exports =
class PaneContainerView extends View
  Delegator.includeInto(this)

  @delegatesMethod 'saveAll', toProperty: 'model'

  @content: ->
    @div class: 'panes'

  constructor: (@element) ->
    super
    @subscriptions = new CompositeDisposable

  setModel: (@model) ->
    @subscriptions.add @model.onDidChangeActivePaneItem(@onActivePaneItemChanged)

  getRoot: ->
    view = atom.views.getView(@model.getRoot())
    view.__spacePenView ? view

  onActivePaneItemChanged: (activeItem) =>
    @trigger 'pane-container:active-pane-item-changed', [activeItem]

  confirmClose: ->
    @model.confirmClose()

  getPaneViews: ->
    @find('atom-pane').views()

  indexOfPane: (paneView) ->
    @getPaneViews().indexOf(paneView.view())

  paneAtIndex: (index) ->
    @getPaneViews()[index]

  eachPaneView: (callback) ->
    callback(paneView) for paneView in @getPaneViews()
    paneViewAttached = (e) -> callback($(e.target).view())
    @on 'pane:attached', paneViewAttached
    off: => @off 'pane:attached', paneViewAttached

  getFocusedPane: ->
    @find('atom-pane:has(:focus)').view()

  getActivePane: ->
    deprecate("Use PaneContainerView::getActivePaneView instead.")
    @getActivePaneView()

  getActivePaneView: ->
    atom.views.getView(@model.getActivePane()).__spacePenView

  getActivePaneItem: ->
    @model.getActivePaneItem()

  getActiveView: ->
    @getActivePaneView()?.activeView

  paneForUri: (uri) ->
    atom.views.getView(@model.paneForURI(uri)).__spacePenView

  focusNextPaneView: ->
    @model.activateNextPane()

  focusPreviousPaneView: ->
    @model.activatePreviousPane()

  focusPaneViewAbove: ->
    @element.focusPaneViewAbove()

  focusPaneViewBelow: ->
    @element.focusPaneViewBelow()

  focusPaneViewOnLeft: ->
    @element.focusPaneViewOnLeft()

  focusPaneViewOnRight: ->
    @element.focusPaneViewOnRight()

  getPanes: ->
    deprecate("Use PaneContainerView::getPaneViews() instead")
    @getPaneViews()
