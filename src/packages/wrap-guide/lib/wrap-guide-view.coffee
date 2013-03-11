{View} = require 'space-pen'
$ = require 'jquery'
_ = nodeRequire 'underscore'

module.exports =
class WrapGuideView extends View
  @activate: ->
    rootView.eachEditor (editor) ->
      editor.underlayer.append(new WrapGuideView(editor)) if editor.attached

  @content: ->
    @div class: 'wrap-guide'

  initialize: (@editor) ->
    @observeConfig 'editor.fontSize', => @updateGuide()
    @subscribe @editor, 'editor:path-changed', => @updateGuide()
    @subscribe @editor, 'editor:min-width-changed', => @updateGuide()
    @subscribe $(window), 'resize', => @updateGuide()

  getDefaultColumn: ->
    config.get('editor.preferredLineLength') ? 80

  getGuideColumn: (path) ->
    customColumns = config.get('wrapGuide.columns')
    return @getDefaultColumn() unless _.isArray(customColumns)
    for customColumn in customColumns
      continue unless _.isObject(customColumn)
      pattern = customColumn['pattern']
      continue unless pattern
      return parseInt(customColumn['column']) if new RegExp(pattern).test(path)
    @getDefaultColumn()

  updateGuide: ->
    column = @getGuideColumn(@editor.getPath(), @defaultColumn)
    if column > 0
      columnWidth = @editor.charWidth * column
      if columnWidth < @editor.layerMinWidth or columnWidth < @editor.width()
        @css('left', columnWidth).show()
      else
        @hide()
    else
      @hide()
