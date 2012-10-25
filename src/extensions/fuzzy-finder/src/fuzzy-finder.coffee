{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
Editor = require 'editor'

module.exports =
class FuzzyFinder extends SelectList
  @activate: (rootView) ->
    requireStylesheet 'select-list.css'
    requireStylesheet 'fuzzy-finder.css'
    @instance = new FuzzyFinder(rootView)
    rootView.command 'fuzzy-finder:toggle-file-finder', => @instance.toggleFileFinder()
    rootView.command 'fuzzy-finder:toggle-buffer-finder', => @instance.toggleBufferFinder()

  @viewClass: ->
    [super, 'fuzzy-finder'].join(' ')

  allowActiveEditorChange: null
  maxItems: 10

  initialize: (@rootView) ->
    super

  itemForElement: (path) ->
    $$ -> @li path

  confirmed : (path) ->
    return unless path.length
    @cancel()
    @rootView.open(path, {@allowActiveEditorChange})

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  toggleFileFinder: ->
    if @hasParent()
      @cancel()
    else
      return unless @rootView.project.getPath()?
      @allowActiveEditorChange = false
      @populateProjectPaths()
      @attach()

  toggleBufferFinder: ->
    if @hasParent()
      @cancel()
    else
      @allowActiveEditorChange = true
      @populateOpenBufferPaths()
      @attach() if @paths?.length

  populateProjectPaths: ->
    @setArray(@rootView.project.getFilePaths())

  populateOpenBufferPaths: ->
    @paths = @rootView.getOpenBufferPaths().map (path) =>
      @rootView.project.relativize(path)
    @setArray(@paths)

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
