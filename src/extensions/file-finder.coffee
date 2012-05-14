{View, $$} = require 'space-pen'
stringScore = require 'stringscore'
fuzzyFilter = require 'fuzzy-filter'
Editor = require 'editor'

module.exports =
class FileFinder extends View
  @activate: (rootView) ->
    @instance = new FileFinder(rootView)

  @content: ->
    @div class: 'file-finder', =>
      @ol outlet: 'pathList'
      @subview 'miniEditor', new Editor(mini: true)

  paths: null
  maxResults: null

  initialize: (@rootView) ->
    requireStylesheet 'file-finder.css'
    @maxResults = 10

    @rootView.on 'file-finder:toggle', => @toggle()

    @on 'file-finder:cancel', => @detach()
    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'file-finder:select-file', => @select()

    @miniEditor.buffer.on 'change', => @populatePathList() if @hasParent()
    @miniEditor.off 'move-up move-down'

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach() if @rootView.project.getPath()?

  attach: ->
    @rootView.project.getFilePaths().done (@paths) => @populatePathList()
    @rootView.append(this)
    @miniEditor.focus()
    @miniEditor.on 'focusout', => @detach()

  detach: ->
    console.log "in detach, focusing root view"
    @miniEditor.off 'focusout'
    @rootView.focus()
    super
    @miniEditor.setText('')

  populatePathList: ->
    @pathList.empty()
    for path in @findMatches(@miniEditor.buffer.getText())
      @pathList.append $$ -> @li path

    @pathList.children('li:first').addClass 'selected'

  findSelectedLi: ->
    @pathList.children('li.selected')

  select: ->
    selectedLi = @findSelectedLi()
    return unless selectedLi.length
    @rootView.open(selectedLi.text())
    @detach()

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
