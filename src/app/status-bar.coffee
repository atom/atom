{View} = require 'space-pen'

module.exports =
class StatusBar extends View
  @initialize: (rootView) ->
    for editor in rootView.editors()
      @appendToEditorPane(editor)

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(editor)

  @appendToEditorPane: (editor) ->
    if pane = editor.pane()
      pane.append(new StatusBar(editor))

  @content: ->
    @div class: 'status-bar'

  initialize: (@editor) ->
