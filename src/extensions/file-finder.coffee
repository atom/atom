{View, $$} = require 'space-pen'
stringScore = require 'stringscore'
fuzzyFilter = require 'fuzzy-filter'
Editor = require 'editor'

module.exports =
class FileFinder extends View
  @activate: (rootView) ->
    @instance = new FileFinder(rootView)
    rootView.on 'file-finder:toggle', => @instance.toggle()

  @content: ->
    @div class: 'file-finder', =>
      @ol outlet: 'pathList'
      @subview 'editor', new Editor(mini: true)

  paths: null
  maxResults: null

  initialize: (@rootView) ->
    requireStylesheet 'file-finder.css'
    @maxResults = 10

    @on 'file-finder:cancel', => @detach()
    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'file-finder:select-file', => @select()

    @editor.buffer.on 'change', => @populatePathList() if @hasParent()
    @editor.off 'move-up move-down'

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach() if @rootView.project.path?

  attach: ->
    @rootView.project.getFilePaths().done (@paths) => @populatePathList()
    @rootView.append(this)
    @editor.focus()

  detach: ->
    @rootView.focus()
    super
    @editor.setText('')

  populatePathList: ->
    @pathList.empty()
    for path in @findMatches(@editor.buffer.getText())
      @pathList.append $$ -> @li path

    @pathList.children('li:first').addClass 'selected'

  findSelectedLi: ->
    @pathList.children('li.selected')

  select: ->
    selectedLi = @findSelectedLi()
    return unless selectedLi.length
    @rootView.open(selectedLi.text())
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
