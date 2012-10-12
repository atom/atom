{View, $$} = require 'space-pen'
stringScore = require 'stringscore'
fuzzyFilter = require 'fuzzy-filter'
$ = require 'jquery'
Editor = require 'editor'

module.exports =
class FuzzyFinder extends View
  @activate: (rootView) ->
    @instance = new FuzzyFinder(rootView)

  @content: ->
    @div class: 'fuzzy-finder', =>
      @ol outlet: 'pathList'
      @subview 'miniEditor', new Editor(mini: true)

  paths: null
  allowActiveEditorChange: null
  maxResults: null

  initialize: (@rootView) ->
    requireStylesheet 'fuzzy-finder.css'
    @maxResults = 10

    @rootView.on 'fuzzy-finder:toggle-file-finder', => @toggleFileFinder()
    @rootView.on 'fuzzy-finder:toggle-buffer-finder', => @toggleBufferFinder()

    @on 'fuzzy-finder:cancel', => @detach()
    @on 'core:move-up', => @moveUp()
    @on 'core:move-down', => @moveDown()
    @on 'fuzzy-finder:select-path', => @select()
    @on 'mousedown', 'li', (e) => @entryClicked(e)

    @miniEditor.getBuffer().on 'change', => @populatePathList() if @hasParent()
    @miniEditor.off 'core:move-up core:move-down'

  toggleFileFinder: ->
    if @hasParent()
      @detach()
    else
      return unless @rootView.project.getPath()?
      @allowActiveEditorChange = false
      @populateProjectPaths()
      @attach()

  toggleBufferFinder: ->
    if @hasParent()
      @detach()
    else
      @allowActiveEditorChange = true
      @populateOpenBufferPaths()
      @attach() if @paths?.length

  populateProjectPaths: ->
    @paths = @rootView.project.getFilePaths()
    @populatePathList()

  populateOpenBufferPaths: ->
    @paths = @rootView.getOpenBufferPaths().map (path) =>
      @rootView.project.relativize(path)
    @populatePathList() if @paths?.length

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
    @miniEditor.on 'focusout', => @detach()

  detach: ->
    @miniEditor.off 'focusout'
    @rootView.focus()
    super
    @miniEditor.setText('')

  populatePathList: ->
    @pathList.empty()
    for path in @findMatches(@miniEditor.getText())
      @pathList.append $$ -> @li path

    @pathList.children('li:first').addClass 'selected'

  findSelectedLi: ->
    @pathList.children('li.selected')

  open : (path) ->
    return unless path.length
    @rootView.open(path, {@allowActiveEditorChange})
    @detach()

  select: ->
    @open(@findSelectedLi().text())

  entryClicked: (e) ->
    @open($(e.currentTarget).text())
    false

  moveUp: ->
    selected = @findSelectedLi().removeClass('selected')

    if selected.filter(':not(:first-child)').length is 0
      selected = @pathList.children('li:last')
    else
      selected = selected.prev()
    selected.addClass('selected')

  moveDown: ->
    selected = @findSelectedLi().removeClass('selected')

    if selected.filter(':not(:last-child)').length is 0
      selected = @pathList.children('li:first')
    else
      selected = selected.next()
    selected.addClass('selected')

  findMatches: (query) ->
    fuzzyFilter(@paths, query, maxResults: @maxResults)
