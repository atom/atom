$ = require 'jquery'
{View} = require 'space-pen'
_ = require 'underscore'
TabView = require './tab-view'

module.exports =
class TabBarView extends View
  @content: ->
    @ul class: "tabs sortable-list"

  initialize: (@pane) ->
    @on 'dragstart', '.sortable', @onDragStart
    @on 'dragend', '.sortable', @onDragEnd
    @on 'dragover', @onDragOver
    @on 'drop', @onDrop

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
    tab.updateTitle()

  removeTabForItem: (item) ->
    @tabForItem(item).remove()
    tab.updateTitle() for tab in @getTabs()

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
    unless @shouldAllowDrag(event)
      event.preventDefault()
      return

    event.originalEvent.dataTransfer.setData 'atom-event', true

    el = $(event.target).closest('.sortable')
    el.addClass 'is-dragging'
    event.originalEvent.dataTransfer.setData 'sortable-index', el.index()

    pane = $(event.target).closest('.pane')
    paneIndex = @paneContainer.indexOfPane(pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex

  onDragEnd: (event) =>
    @find(".is-dragging").removeClass 'is-dragging'

  onDragOver: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') == true
      event.preventDefault()
      event.stopPropagation()
      return

    event.preventDefault()
    currentDropTargetIndex = @find(".is-drop-target").index()
    newDropTargetIndex = @getDropTargetIndex(event)

    if newDropTargetIndex != currentDropTargetIndex
      @children().removeClass 'is-drop-target drop-target-is-after'
      sortableObjects = @find(".sortable")
      if newDropTargetIndex < sortableObjects.length
        sortableObjects.eq(newDropTargetIndex).addClass 'is-drop-target'
      else
        sortableObjects.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'


  onDrop: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') == true
      event.preventDefault()
      event.stopPropagation()
      return

    event.stopPropagation()
    @children('.is-drop-target').removeClass 'is-drop-target'
    @children('.drop-target-is-after').removeClass 'drop-target-is-after'

    dataTransfer  = event.originalEvent.dataTransfer
    fromIndex     = parseInt(dataTransfer.getData('sortable-index'))
    fromPaneIndex = parseInt(dataTransfer.getData('from-pane-index'))
    fromPane      = @paneContainer.paneAtIndex(fromPaneIndex)
    toIndex       = @getDropTargetIndex(event)
    toPane        = $(event.target).closest('.pane').view()
    draggedTab    = fromPane.find(".tabs .sortable:eq(#{fromIndex})").view()
    item          = draggedTab.item

    if toPane is fromPane
      toIndex-- if fromIndex < toIndex
      toPane.moveItem(item, toIndex)
    else
      fromPane.moveItemToPane(item, toPane, toIndex--)
    toPane.showItem(item)
    toPane.focus()

  getDropTargetIndex: (event) ->
    el = $(event.target).closest('.sortable')
    el = $(event.target).find('.sortable').last()  if el.length == 0

    elementCenter = el.offset().left + el.width() / 2

    if event.originalEvent.pageX < elementCenter
      el.index()
    else if el.next().length > 0
      el.next().index()
    else
      el.index() + 1
