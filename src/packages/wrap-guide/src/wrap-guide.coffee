{View} = require 'space-pen'

module.exports =
class WrapGuide extends View
  @activate: (rootView, state, config) ->
    requireStylesheet 'wrap-guide.css'

    for editor in rootView.getEditors()
      if rootView.parents('html').length
        @appendToEditorPane(rootView, editor, config)

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(rootView, editor, config)

  @appendToEditorPane: (rootView, editor, config) ->
    if underlayer = editor.pane()?.find('.underlayer')
      underlayer.append(new WrapGuide(rootView, editor, config))

  @content: ->
    @div class: 'wrap-guide'

  getGuideColumn: null
  defaultColumn: 80

  initialize: (@rootView, @editor, options = {}) =>
    if typeof options.getGuideColumn is 'function'
      @getGuideColumn = options.getGuideColumn
    else
      @getGuideColumn = (path, defaultColumn) -> defaultColumn

    @observeConfig 'editor.fontSize', => @updateGuide(@editor)
    @subscribe @editor, 'editor-path-change', => @updateGuide(@editor)
    @subscribe @editor, 'before-remove', => @rootView.off('.wrap-guide')

  updateGuide: (editor) ->
    column = @getGuideColumn(editor.getPath(), @defaultColumn)
    if column > 0
      @css('left', "#{editor.charWidth * column}px").show()
    else
      @hide()
