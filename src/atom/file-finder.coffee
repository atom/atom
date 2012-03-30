$ = require 'jquery'
{View} = require 'space-pen'
stringScore = require 'stringscore'
Editor = require 'editor'

module.exports =
class FileFinder extends View
  @content: ->
    @div class: 'file-finder', =>
      @ol outlet: 'pathList'
      @subview 'editor', new Editor

  paths: null
  maxResults: null

  initialize: ({@paths, @selected}) ->
    requireStylesheet 'file-finder.css'
    @maxResults = 10
    @previousFocusedElement = $(document.activeElement)

    @populatePathList()
    window.keymap.bindKeys ".file-finder .editor",
      'enter': 'file-finder:select-file',
      'escape': 'file-finder:close'

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

  remove: ->
    super()
    @previousFocusedElement.focus()

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
    if not query
      paths = @paths
    else
      scoredPaths = ({path, score: stringScore(path, query)} for path in @paths)
      scoredPaths.sort (a, b) ->
        if a.score > b.score then -1
        else if a.score < b.score then 1
        else 0
      window.x = scoredPaths

      paths = (pathAndScore.path for pathAndScore in scoredPaths when pathAndScore.score > 0)

    paths.slice 0, @maxResults
