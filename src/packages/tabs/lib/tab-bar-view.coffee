$ = require 'jquery'
_ = require 'underscore'
SortableList = require 'sortable-list'
TabView = require './tab-view'

module.exports =
class TabBarView extends SortableList
  @content: ->
    @ul class: "tabs #{@viewClass()}"

  initialize: (@pane) ->
    super
    @addTabForItem(item) for item in @pane.getItems()

    @pane.on 'pane:item-added', (e, item, index) => @addTabForItem(item, index)
    @pane.on 'pane:item-removed', (e, item) => @removeTabForItem(item)
    @pane.on 'pane:active-item-changed', => @updateActiveTab()

    @updateActiveTab()

#     @setActiveTab(@editor.getActiveEditSessionIndex())

#     @editor.on 'editor:edit-session-added', (e, editSession) => @addTabForEditSession(editSession)
#     @editor.on 'editor:edit-session-removed', (e, editSession, index) => @removeTabAtIndex(index)
#     @editor.on 'editor:edit-session-order-changed', (e, editSession, fromIndex, toIndex) =>
#       fromTab = @find(".tab:eq(#{fromIndex})")
#       toTab = @find(".tab:eq(#{toIndex})")
#       fromTab.detach()
#       if fromIndex < toIndex
#         fromTab.insertAfter(toTab)
#       else
#         fromTab.insertBefore(toTab)

    @on 'click', '.tab', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.showItem(tab.item)
      @pane.focus()

    @on 'click', '.tab .close-icon', (e) =>
      tab = $(e.target).closest('.tab').view()
      @pane.removeItem(tab.item)
      false

    @pane.prepend(this)

  addTabForItem: (item, index) ->
    tabView = new TabView(item, @pane)
    followingTab = @tabAtIndex(index) if index?
    if followingTab
      tabView.insertBefore(followingTab)
    else
      @append(tabView)

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

  removeTabAtIndex: (index) ->
    @find(".tab:eq(#{index})").remove()

  containsEditSession: (editor, editSession) ->
    for session in editor.editSessions
      return true if editSession.getPath() is session.getPath()

  shouldAllowDrag: (event) ->
    panes = rootView.find('.pane')
    !(panes.length == 1 && panes.find('.sortable').length == 1)

  onDragStart: (event) =>
    super

    pane = $(event.target).closest('.pane')
    paneIndex = rootView.indexOfPane(pane)
    event.originalEvent.dataTransfer.setData 'from-pane-index', paneIndex

  onDrop: (event) =>
    super

    droppedNearTab = @getSortableElement(event)
    transfer = event.originalEvent.dataTransfer
    previousDraggedTabIndex = transfer.getData 'sortable-index'

    fromPaneIndex = ~~transfer.getData 'from-pane-index'
    toPaneIndex   = rootView.indexOfPane($(event.target).closest('.pane'))
    fromPane      = $(rootView.find('.pane')[fromPaneIndex])
    fromEditor    = fromPane.find('.editor').view()
    draggedTab    = fromPane.find(".#{TabBarView.viewClass()} .sortable:eq(#{previousDraggedTabIndex})")

    if draggedTab.is(droppedNearTab)
      fromEditor.focus()
      return

    if fromPaneIndex == toPaneIndex
      droppedNearTab = @getSortableElement(event)
      fromIndex = draggedTab.index()
      toIndex = droppedNearTab.index()
      toIndex++ if fromIndex > toIndex
      fromEditor.moveEditSessionToIndex(fromIndex, toIndex)
      fromEditor.focus()
    else
      toEditor = rootView.find(".pane:eq(#{toPaneIndex}) > .editor").view()
      if @containsEditSession(toEditor, fromEditor.editSessions[draggedTab.index()])
        fromEditor.focus()
      else
        fromEditor.moveEditSessionToEditor(draggedTab.index(), toEditor, droppedNearTab.index() + 1)
        toEditor.focus()
