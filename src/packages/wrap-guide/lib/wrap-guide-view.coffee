{View} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class WrapGuideView extends View
  @activate: ->
    rootView.eachEditor (editor) ->
      if editor.attached and editor.getPane()
        editor.underlayer.append(new WrapGuideView(editor))

  @content: ->
    @div class: 'wrap-guide'

  initialize: (@editor) ->
    @observeConfig 'editor.fontSize', => @updateGuide()
    @subscribe @editor, 'editor:path-changed', => @updateGuide()
    @subscribe @editor, 'editor:min-width-changed', => @updateGuide()
    @subscribe $(window), 'resize', => @updateGuide()

  getDefaultColumn: ->
    config.getPositiveInt('editor.preferredLineLength', 80)

  getGuideColumn: (path) ->
    customColumns = config.get('wrapGuide.columns')
    return @getDefaultColumn() unless _.isArray(customColumns)
    for customColumn in customColumns when _.isObject(customColumn)
      {pattern, column} = customColumn
      return parseInt(column) if pattern and new RegExp(pattern).test(path)
    @getDefaultColumn()

  updateGuide: ->
    column = @getGuideColumn(@editor.getPath())
    if column > 0
      columnWidth = @editor.charWidth * column
      if columnWidth < @editor.layerMinWidth or columnWidth < @editor.width()
        @css('left', columnWidth).show()
      else
        @hide()
    else
      @hide()
