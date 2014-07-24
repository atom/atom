{find} = require 'underscore-plus'
{Model} = require 'theorist'
Serializable = require 'serializable'
Pane = require './pane'

module.exports =
class PaneContainer extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @properties
    activePane: null

  @version: 2

  constructor: ({@orientation, panes}={}) ->
    super
    @panes = []
    @addPane(pane) for pane in panes ? []
    @addPane(new Pane()) if @panes.length == 0

    @activePane = @getPanes()[0]

  deserializeParams: (params) ->
    params.orientation = params.orientation ? "vertical"
    # params.activePane = params.panes.find((pane) -> pane.id is params.activePaneId)
    # @destroyEmptyPanes() if atom.config.get('core.destroyEmptyPanes')
    params

  serializeParams: (params) ->
    # panes: @panes.map (pane) -> pane.serialize()
    # activePaneId: @activePane.id
    params

  getViewClass: ->
    require './pane-container-view'

  addPane: (pane, position) ->
    switch position
      when undefined
        paneOrientation = @orientation
      when 'top', 'bottom'
        paneOrientation = 'horizontal'
      else
        paneOrientation = 'vertical'

    if paneOrientation == @orientation
      @panes.push(pane)
    else
      @unsubscribe(pane) for pane in @panes
      wrappedPaneContainer = new PaneContainer({@orientation, @panes})
      newPaneContainer = new PaneContainer({orientation:paneOrientation, panes:[wrappedPaneContainer, pane]})
      @panes = []
      @addPane(newPaneContainer)

    @subscribe pane, 'destroyed', => @onPaneDestroyed(pane)
    @subscribe pane, 'activated', => @activePane = pane
    @emit 'panes-reordered'

  onPaneDestroyed: (pane) ->
    @unsubscribe(pane)
    paneIndex = @panes.indexOf(pane)
    return if paneIndex == -1
    @panes.splice(paneIndex, 1)

  getPanes: ->
    allPanes = []
    for pane in @panes
      if pane instanceof PaneContainer
        allPanes = allPanes.concat(pane.getPanes())
      else
        allPanes.push(pane)

    allPanes

  getActivePane: ->
    @activePane

  getActivePaneItem: ->
    @activePane.getActiveItem()

  paneForUri: (uri) ->
    find @getPanes(), (pane) -> pane.itemForUri(uri)?

  saveAll: ->
    pane.saveItems() for pane in @getPanes()

  destroyEmptyPanes: ->
    pane.destroy() for pane in @getPanes() when pane.items.length is 0

  itemDestroyed: (item) ->
    @emit 'item-destroyed', item

  # Called by Model superclass when destroyed
  destroyed: ->
    pane.destroy() for pane in @getPanes()
