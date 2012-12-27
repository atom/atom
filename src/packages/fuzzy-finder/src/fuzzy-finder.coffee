{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'

module.exports =
class FuzzyFinder extends SelectList
  @activate: (rootView) ->
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
    $(window).on 'focus', => @projectPaths = null
    @observeConfig 'fuzzy-finder.ignoredNames', (ignoredNames) =>
      @projectPaths = null

  itemForElement: (path) ->
    $$ ->
      @li =>
        ext = fs.extension(path)
        if fs.isCompressedExtension(ext)
          typeClass = 'compressed-name'
        else if fs.isImageExtension(ext)
          typeClass = 'image-name'
        else if fs.isPdfExtension(ext)
          typeClass = 'pdf-name'
        else
          typeClass = 'text-name'
        @span fs.base(path), class: "file #{typeClass}"
        if folder = fs.directory(path)
          @span "- #{folder}/", class: 'directory'

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
