{View} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class WrapGuide extends View
  @activate: (rootView, state) ->
    requireStylesheet 'wrap-guide.css'

    for editor in rootView.getEditors()
      if rootView.parents('html').length
        @appendToEditorPane(rootView, editor)

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(rootView, editor)

  @appendToEditorPane: (rootView, editor, config) ->
    if underlayer = editor.pane()?.find('.underlayer')
      underlayer.append(new WrapGuide(rootView, editor))

  @content: ->
    @div class: 'wrap-guide'

  getGuideColumn: null
  defaultColumn: 80

  initialize: (@rootView, @editor) =>
    @observeConfig 'editor.fontSize', => @updateGuide()
    @subscribe @editor, 'editor-path-change', => @updateGuide()
    @subscribe @editor, 'editor:min-width-changed', => @updateGuide()
    @subscribe $(window), 'resize', => @updateGuide()

  getGuideColumn: (path) ->
    customColumns = config.get('wrapGuide.columns')
    return @defaultColumn unless _.isArray(customColumns)
    for customColumn in customColumns
      continue unless _.isObject(customColumn)
      regex = customColumn['pattern']
      continue unless regex
      return parseInt(customColumn['column']) if new RegExp(regex).test(path)
    @defaultColumn

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
