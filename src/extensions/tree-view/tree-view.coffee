{View, $$} = require 'space-pen'
Directory = require 'directory'
DirectoryView = require 'tree-view/directory-view'
FileView = require 'tree-view/file-view'
MoveDialog = require 'tree-view/move-dialog'
AddDialog = require 'tree-view/add-dialog'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class TreeView extends View
  @activate: (rootView, state) ->
    requireStylesheet 'tree-view.css'

    if state
      @treeView = TreeView.deserialize(state, rootView)
    else
      @treeView = new TreeView(rootView)

    rootView.horizontal.prepend(@treeView)

  @content: (rootView) ->
    @div class: 'tree-view', tabindex: -1, =>
      @subview 'root', new DirectoryView(directory: rootView.project.getRootDirectory(), isExpanded: true)

  @deserialize: (state, rootView) ->
    treeView = new TreeView(rootView)
    treeView.root.deserializeEntryExpansionStates(state.directoryExpansionStates)
    treeView.selectEntryForPath(state.selectedPath)
    treeView

  @serialize: ->
    @treeView.serialize()

  root: null

  initialize: (@rootView) ->
    @on 'click', '.entry', (e) =>
      entry = $(e.currentTarget).view()
      @selectEntry(entry)
      @openSelectedEntry() if (entry instanceof FileView)
      false

    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'tree-view:expand-directory', => @expandDirectory()
    @on 'tree-view:collapse-directory', => @collapseDirectory()
    @on 'tree-view:open-selected-entry', => @openSelectedEntry()
    @on 'tree-view:move', => @move()
    @on 'tree-view:add', => @add()
    @on 'tree-view:directory-modified', => @selectActiveFile()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()

    @on 'tree-view:unfocus', => @rootView.activeEditor()?.focus()
    @rootView.on 'tree-view:focus', => this.focus()

  serialize: ->
    directoryExpansionStates: @root.serializeEntryExpansionStates()
    selectedPath: @selectedEntry()?.getPath()

  deactivate: ->
    @root.unwatchEntries()

  selectActiveFile: ->
    activeFilePath = @rootView.activeEditor()?.buffer.path
    @selectEntryForPath(activeFilePath)

  selectEntryForPath: (path) ->
    for element in @find(".entry")
      view = $(element).view()
      if view.getPath() == path
        @selectEntry(view)
        return

  moveDown: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if selectedEntry.is('.expanded.directory')
        return if @selectEntry(selectedEntry.find('.entry:first'))
      return if @selectEntry(selectedEntry.next())
      return if @selectEntry(selectedEntry.closest('.directory').next())
    else
      @selectEntry(@root)

  moveUp: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      return if @selectEntry(selectedEntry.prev())
      return if @selectEntry(selectedEntry.parents('.directory').first())
    else
      @selectEntry(@find('.entry').last())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if (selectedEntry instanceof DirectoryView)

  collapseDirectory: ->
    selectedEntry = @selectedEntry()
    directory = selectedEntry.closest('.expanded.directory').view()
    directory.collapse()
    @selectEntry(directory)

  openSelectedEntry: ->
    selectedEntry = @selectedEntry()
    if (selectedEntry instanceof DirectoryView)
      selectedEntry.view().toggleExpansion()
    else if (selectedEntry instanceof FileView)
      @rootView.open(selectedEntry.getPath())
      @rootView.focus()

  move: ->
    @rootView.append(new MoveDialog(@rootView.project, @selectedEntry().getPath()))

  add: ->
    @rootView.append(new AddDialog(@rootView, @selectedEntry().getPath()))

  selectedEntry: ->
    @find('.selected')?.view()

  selectEntry: (entry) ->
    return false unless entry.get(0)
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

