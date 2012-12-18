{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
$ = require 'jquery'
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
  projectPaths: null

  initialize: (@rootView) ->
    super
    $(window).on 'focus', => @array = null
    @observeConfig 'fuzzy-finder.ignoredNames', (ignoredNames) =>
      @projectPaths = null

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
    if @projectPaths?.length > 0
      @setArray(@projectPaths)
    else
      @setLoading("Indexing...")
      @rootView.project.getFilePaths().done (paths) =>
        ignoredNames = config.get("fuzzy-finder.ignoredNames")
        @projectPaths = paths
        if ignoredNames
          @projectPaths = @projectPaths.filter (path) ->
            for segment in path.split("/")
              return false if _.contains(ignoredNames, segment)
            return true

        @setArray(@projectPaths)

  populateOpenBufferPaths: ->
    @paths = @rootView.getOpenBufferPaths().map (path) =>
      @rootView.project.relativize(path)
    @setArray(@paths)

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
