{View} = require 'space-pen'
$ = require 'jquery'

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

    @observeConfig 'editor.fontSize', => @updateGuide()
    @subscribe @editor, 'editor-path-change', => @updateGuide()
    @subscribe @editor, 'editor:min-width-changed', => @updateGuide()
    @subscribe $(window), 'resize', => @updateGuide()

  updateGuide: ->
    column = @getGuideColumn(@editor.getPath(), @defaultColumn)
    if column > 0
      columnWidth = @editor.charWidth * column
      if columnWidth < @editor.layerMinWidth or columnWidth < @editor.width()
        @css('left', "#{columnWidth}px").show()
      else
        @hide()
    else
      @hide()
