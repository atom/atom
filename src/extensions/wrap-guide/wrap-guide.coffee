{View} = require 'space-pen'

module.exports =
class WrapGuide extends View
  @activate: (rootView) ->
    requireStylesheet 'wrap-guide.css'

    for editor in rootView.getEditors()
      @appendToEditorPane(rootView, editor) if rootView.parents('html').length

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(rootView, editor)

  @appendToEditorPane: (rootView, editor) ->
    if parent = editor.pane()?.find('.editor')
      parent.append(new WrapGuide(rootView, editor))

  @content: ->
    @div class: 'wrap-guide'

  column: 80

  initialize: (@rootView, @editor) =>
    @updateGuide(@editor)
    @editor.on 'editor-path-change', => @updateGuide(@editor)
    @rootView.on 'font-size-change', => @updateGuide(@editor)

  updateGuide: (editor) ->
    width = editor.charWidth * @column
    @css("left", width + "px")
