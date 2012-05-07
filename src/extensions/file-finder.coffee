$ = require 'jquery'
{View} = require 'space-pen'
stringScore = require 'stringscore'
fuzzyFilter = require 'fuzzy-filter'
Editor = require 'editor'

module.exports =
class FileFinder extends View
  @content: ->
    @div class: 'file-finder', =>
      @ol outlet: 'pathList'
      @subview 'editor', new Editor(mini: true)

  paths: null
  maxResults: null

  initialize: ({@paths, @selected}) ->
    requireStylesheet 'file-finder.css'
    @maxResults = 10

    @populatePathList()

    @on 'file-finder:close', => @remove()
    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'file-finder:select-file', => @select()

    @editor.addClass 'single-line'
    @editor.buffer.on 'change', => @populatePathList()
    @editor.off 'move-up move-down'

  populatePathList: ->
    @pathList.empty()
    for path in @findMatches(@editor.buffer.getText())
      @pathList.append $("<li>#{path}</li>")

    @pathList.children('li:first').addClass 'selected'

  findSelectedLi: ->
    @pathList.children('li.selected')

  select: ->
    filePath = @findSelectedLi().text()
    @selected(filePath) if filePath and @selected
    @remove()

  moveUp: ->
    @findSelectedLi()
      .filter(':not(:first-child)')
      .removeClass('selected')
      .prev()
      .addClass('selected')

  moveDown: ->
    @findSelectedLi()
      .filter(':not(:last-child)')
      .removeClass('selected')
      .next()
      .addClass('selected')

  findMatches: (query) ->
    fuzzyFilter(@paths, query, maxResults: @maxResults)

  remove: ->
    $('#root-view').focus()
    super
