$ = require 'jquery'
SortableList = require 'sortable-list'
Tab = require './tab'

module.exports =
class TabView extends SortableList
  @activate: ->
    rootView.eachEditor (editor) =>
      @prependToEditorPane(editor) if editor.attached

  @prependToEditorPane: (editor) ->
    if pane = editor.pane()
      pane.prepend(new TabView(editor))

  @content: ->
    @ul class: "tabs #{@viewClass()}"

  initialize: (@editor) ->
    super

    @addTabForEditSession(editSession) for editSession in @editor.editSessions

    @setActiveTab(@editor.getActiveEditSessionIndex())
    @editor.on 'editor:active-edit-session-changed', (e, editSession, index) => @setActiveTab(index)
    @editor.on 'editor:edit-session-added', (e, editSession) => @addTabForEditSession(editSession)
    @editor.on 'editor:edit-session-removed', (e, editSession, index) => @removeTabAtIndex(index)
    @editor.on 'editor:edit-session-order-changed', (e, editSession, fromIndex, toIndex) =>
      fromTab = @find(".tab:eq(#{fromIndex})")
      toTab = @find(".tab:eq(#{toIndex})")
      fromTab.detach()
      if fromIndex < toIndex
        fromTab.insertAfter(toTab)
      else
        fromTab.insertBefore(toTab)

    @on 'click', '.tab', (e) =>
      @editor.setActiveEditSessionIndex($(e.target).closest('.tab').index())
      @editor.focus()

    @on 'click', '.tab .close-icon', (e) =>
      index = $(e.target).closest('.tab').index()
      @editor.destroyEditSessionIndex(index)
      false

  addTabForEditSession: (editSession) ->
    @append(new Tab(editSession, @editor))

  setActiveTab: (index) ->
    @find(".tab.active").removeClass('active')
    @find(".tab:eq(#{index})").addClass('active')

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
    draggedTab    = fromPane.find(".#{TabView.viewClass()} .sortable:eq(#{previousDraggedTabIndex})")

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
