$ = require 'jquery'
SortableList = require 'sortable-list'
Tab = require 'tabs/src/tab'

module.exports =
class Tabs extends SortableList
  @activate: (rootView) ->
    rootView.eachEditor (editor) =>
      @prependToEditorPane(rootView, editor) if editor.attached

  @prependToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.prepend(new Tabs(editor))

  @content: ->
    @ul class: "tabs #{@viewClass()}"

  initialize: (@editor) ->
    super

    for editSession, index in @editor.editSessions
      @addTabForEditSession(editSession)

    @setActiveTab(@editor.getActiveEditSessionIndex())
    @editor.on 'editor:active-edit-session-changed', (e, editSession, index) => @setActiveTab(index)
    @editor.on 'editor:edit-session-added', (e, editSession) => @addTabForEditSession(editSession)
    @editor.on 'editor:edit-session-removed', (e, editSession, index) => @removeTabAtIndex(index)

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

  onDragStart: (event) =>
    super
    pane = $(event.target).closest('.pane')
    event.originalEvent.dataTransfer.setData 'from-pane-index', pane.index()

  onDrop: (event) =>
    super
    transfer = event.originalEvent.dataTransfer
    previousDraggedTabIndex = transfer.getData 'sortable-index'

    fromPaneIndex = ~~transfer.getData 'from-pane-index'
    toPaneIndex   = ~~$(event.target).closest('.pane').index()
    fromPane      = rootView.find ".pane:nth-child(#{fromPaneIndex + 1})"
    fromEditor    = fromPane.find('.editor').view()

    if fromPaneIndex == toPaneIndex
      toPane   = fromPane
      toEditor = fromEditor
    else
      toPane = rootView.find ".pane:nth-child(#{toPaneIndex + 1})"
      toEditor = toPane.find('.editor').view()

    droppedNearTab = @getSortableElement(event)
    draggedTab     = fromPane.find(".#{Tabs.viewClass()} .sortable:eq(#{previousDraggedTabIndex})")

    draggedTab.remove()
    draggedTab.insertBefore(droppedNearTab)

    currentDraggedTabIndex = draggedTab.index()

    toEditor.editSessions.splice(currentDraggedTabIndex, 0, fromEditor.editSessions.splice(previousDraggedTabIndex, 1)[0])

    @setActiveTab(currentDraggedTabIndex)
    fromEditor.setActiveEditSessionIndex(0)
    toEditor.setActiveEditSessionIndex(currentDraggedTabIndex)
    toEditor.focus()
