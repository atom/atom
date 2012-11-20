$ = require 'jquery'
{View} = require 'space-pen'
Tab = require 'tabs/src/tab'

module.exports =
class Tabs extends View
  @activate: (rootView) ->
    requireStylesheet 'tabs/src/tabs.css'

    for editor in rootView.getEditors()
      @prependToEditorPane(rootView, editor) if rootView.parents('html').length

    rootView.on 'editor-open', (e, editor) =>
      @prependToEditorPane(rootView, editor)

  @prependToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.prepend(new Tabs(editor))

  @content: ->
    @div class: 'tabs'

  initialize: (@editor) ->
    for editSession, index in @editor.editSessions
      @addTabForEditSession(editSession)

    @setActiveTab(@editor.getActiveEditSessionIndex())
    @editor.on 'editor:active-edit-session-changed', (e, editSession, index) => @setActiveTab(index)
    @editor.on 'editor:edit-session-added', (e, editSession) => @addTabForEditSession(editSession)
    @editor.on 'editor:edit-session-removed', (e, editSession, index) => @removeTabAtIndex(index)

    @on 'click', '.tab', (e) =>
      @editor.setActiveEditSessionIndex($(e.target).closest('.tab').index())

  addTabForEditSession: (editSession) ->
    @append(new Tab(editSession))

  setActiveTab: (index) ->
    @find(".tab.active").removeClass('active')
    @find(".tab:eq(#{index})").addClass('active')

  removeTabAtIndex: (index) ->
    @find(".tab:eq(#{index})").remove()
