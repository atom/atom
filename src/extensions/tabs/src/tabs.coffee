{View, $$} = require 'space-pen'

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
      @append $$ ->
        @div class: 'tab', =>
          @div editSession.buffer.getBaseName(), class: 'file-name'

    activeIndex = @editor.getActiveEditSessionIndex()
    @children(":eq(#{activeIndex})").addClass('active')
