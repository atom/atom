$ = require 'jquery'
_ = nodeRequire 'underscore'
SortableList = require 'sortable-list'
TabView = require './tab-view'

module.exports =
class TabBarView extends SortableList
  @content: ->
    @ul class: "tabs #{@viewClass()}"

  initialize: (@pane) ->
    super

    @paneContainer = @pane.getContainer()
    @addTabForItem(item) for item in @pane.getItems()

    @pane.on 'pane:item-added', (e, item, index) => @addTabForItem(item, index)
    @pane.on 'pane:item-moved', (e, item, index) => @moveItemTabToIndex(item, index)
    @pane.on 'pane:item-removed', (e, item) => @removeTabForItem(item)
    @pane.on 'pane:active-item-changed', => @updateActiveTab()

    @updateActiveTab()

    @on 'click', '.tab', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.showItem(tab.item)
      @pane.focus()

    @on 'click', '.tab .close-icon', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.destroyItem(tab.item)
      false

    @pane.prepend(this)

  addTabForItem: (item, index) ->
    @insertTabAtIndex(new TabView(item, @pane), index)

  moveItemTabToIndex: (item, index) ->
    tab = @tabForItem(item)
    tab.detach()
    @insertTabAtIndex(tab, index)

  insertTabAtIndex: (tab, index) ->
    followingTab = @tabAtIndex(index) if index?
    if followingTab
      tab.insertBefore(followingTab)
    else
      @append(tab)

  removeTabForItem: (item) ->
    @tabForItem(item).remove()

  getTabs: ->
    @children('.tab').toArray().map (elt) -> $(elt).view()

  tabAtIndex: (index) ->
    @children(".tab:eq(#{index})").view()

  tabForItem: (item) ->
    _.detect @getTabs(), (tab) -> tab.item is item

  setActiveTab: (tabView) ->
    unless tabView.hasClass('active')
      @find(".tab.active").removeClass('active')
      tabView.addClass('active')

  updateActiveTab: ->
    @setActiveTab(@tabForItem(@pane.activeItem))

  shouldAllowDrag: ->
    (@paneContainer.getPanes().length > 1) or (@pane.getItems().length > 1)

  onDragStart: (event) =>
    super
    pane = $(event.target).closest('.pane')
    paneIndex = @paneContainer.indexOfPane(pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex

  onDrop: (event) =>
    super

    dataTransfer  = event.originalEvent.dataTransfer
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))
    fromPane      = @paneContainer.paneAtIndex(fromPaneIndex)
    toIndex       = @getSortableElement(event).index()
    toPane        = $(event.target).closest('.pane').view()
    draggedTab    = fromPane.find(".tabs .sortable:eq(#{fromIndex})").view()
    item          = draggedTab.item

    if toPane is fromPane
      toIndex++ if fromIndex > toIndex
      toPane.moveItem(item, toIndex)
    else
      fromPane.moveItemToPane(item, toPane, toIndex)
    toPane.showItem(item)
    toPane.focus()
