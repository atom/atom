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
    if lines = editor.pane()?.find('.lines')
      lines.append(new WrapGuide(rootView, editor))

  @content: ->
    @div class: 'wrap-guide'

  initialize: (@rootView, @editor) =>
    @updateGuide(@editor)
    @editor.on 'editor-path-change', => @updateGuide(@editor)
    @rootView.on 'font-size-change', => @updateGuide(@editor)

  updateGuide: (editor) ->
    width = editor.charWidth * 80
    @css("left", width + "px")
