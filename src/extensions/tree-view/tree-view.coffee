{View, $$} = require 'space-pen'
Directory = require 'directory'
DirectoryView = require 'tree-view/directory-view'
FileView = require 'tree-view/file-view'
Dialog = require 'tree-view/dialog'
Native = require 'native'
fs = require 'fs'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class TreeView extends View
  @activate: (rootView, state) ->
    requireStylesheet 'tree-view.css'

    if state
      @instance = TreeView.deserialize(state, rootView)
    else
      @instance = new TreeView(rootView)
      @instance.attach()

  @deactivate: () ->
    @instance.deactivate()

  @serialize: ->
    @instance.serialize()

  @content: (rootView) ->
    @div class: 'tree-view', tabindex: -1, =>
      if rootView.project.getRootDirectory()
        @subview 'root', new DirectoryView(directory: rootView.project.getRootDirectory(), isExpanded: true)

  @deserialize: (state, rootView) ->
    treeView = new TreeView(rootView)
    treeView.root.deserializeEntryExpansionStates(state.directoryExpansionStates)
    treeView.selectEntryForPath(state.selectedPath)
    treeView.focusAfterAttach = state.hasFocus
    treeView.scrollTopAfterAttach = state.scrollTop
    treeView.attach() if state.attached
    treeView

  root: null
  focusAfterAttach: false
  scrollTopAfterAttach: -1
  selectedPath: null

  initialize: (@rootView) ->
    @on 'click', '.entry', (e) => @entryClicked(e)
    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'tree-view:expand-directory', => @expandDirectory()
    @on 'tree-view:collapse-directory', => @collapseDirectory()
    @on 'tree-view:open-selected-entry', => @openSelectedEntry(true)
    @on 'tree-view:move', => @moveSelectedEntry()
    @on 'tree-view:add', => @add()
    @on 'tree-view:remove', => @removeSelectedEntry()
    @on 'tree-view:directory-modified', =>
      if @hasFocus()
        @selectEntryForPath(@selectedPath) if @selectedPath
      else
        @selectActiveFile()
    @on 'tree-view:unfocus', => @rootView.focus()
    @rootView.on 'tree-view:toggle', => @toggle()
    @rootView.on 'tree-view:reveal-active-file', => @revealActiveFile()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()
    @rootView.project.on 'path-change', => @updateRoot()

    @selectEntry(@root) if @root

  afterAttach: (onDom) ->
    @focus() if @focusAfterAttach
    @scrollTop(@scrollTopAfterAttach) if @scrollTopAfterAttach > 0

  serialize: ->
    directoryExpansionStates: @root?.serializeEntryExpansionStates()
    selectedPath: @selectedEntry()?.getPath()
    hasFocus: @hasFocus()
    attached: @hasParent()
    scrollTop: @scrollTop()

  deactivate: ->
    @root?.unwatchEntries()

  toggle: ->
    if @hasFocus()
      @detach()
      @rootView.focus()
    else
      @attach() unless @hasParent()
      @focus()

  attach: ->
    @rootView.horizontal.prepend(this)

  detach: ->
    @scrollTopAfterAttach = @scrollTop()
    super

  hasFocus: ->
    @is(':focus')

  entryClicked: (e) ->
    entry = $(e.currentTarget).view()
    switch e.originalEvent?.detail ? 1
      when 1
        @selectEntry(entry)
        @openSelectedEntry(false) if (entry instanceof FileView)
      when 2
        if entry.is('.selected.file')
          @rootView.getActiveEditor().focus()
        else if entry.is('.selected.directory')
          entry.toggleExpansion()

    false

  updateRoot: ->
    @root?.remove()
    if @rootView.project.getRootDirectory()
      @root = new DirectoryView(directory: @rootView.project.getRootDirectory(), isExpanded: true)
      @append(@root)
    else
      @root = null

  selectActiveFile: ->
    activeFilePath = @rootView.getActiveEditor()?.getPath()
    @selectEntryForPath(activeFilePath) if activeFilePath

  revealActiveFile: ->
    @attach()
    @focus()

    return unless activeFilePath = @rootView.getActiveEditor()?.getPath()

    project = @rootView.project
    activePathComponents = project.relativize(activeFilePath).split('/')
    currentPath = project.getPath().replace(/\/$/, '')
    for pathComponent in activePathComponents
      currentPath += '/' + pathComponent
      entry = @entryForPath(currentPath)
      if entry.hasClass('directory')
        entry.expand()
      else
        @selectEntry(entry)

  entryForPath: (path) ->
    fn = (bestMatchEntry, element) ->
      entry = $(element).view()
      regex = new RegExp("^" + _.escapeRegExp(entry.getPath()))
      if regex.test(path) and entry.getPath().length > bestMatchEntry.getPath().length
        entry
      else
        bestMatchEntry

    @find(".entry").toArray().reduce(fn, @root)

  selectEntryForPath: (path) ->
    @selectEntry(@entryForPath(path))

  moveDown: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if selectedEntry.is('.expanded.directory')
        return if @selectEntry(selectedEntry.find('.entry:first'))
      until @selectEntry(selectedEntry.next())
        selectedEntry = selectedEntry.parents('.entry:first')
        break unless selectedEntry.length
    else
      @selectEntry(@root)

    @scrollToEntry(@selectedEntry())

  moveUp: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if previousEntry = @selectEntry(selectedEntry.prev())
        if previousEntry.is('.expanded.directory')
          @selectEntry(previousEntry.find('.entry:last'))
      else
        @selectEntry(selectedEntry.parents('.directory').first())
    else
      @selectEntry(@find('.entry').last())

    @scrollToEntry(@selectedEntry())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if (selectedEntry instanceof DirectoryView)

  collapseDirectory: ->
    selectedEntry = @selectedEntry()
    if directory = selectedEntry.closest('.expanded.directory').view()
      directory.collapse()
      @selectEntry(directory)

  openSelectedEntry: (changeFocus) ->
    selectedEntry = @selectedEntry()
    if (selectedEntry instanceof DirectoryView)
      selectedEntry.view().toggleExpansion()
    else if (selectedEntry instanceof FileView)
      @rootView.open(selectedEntry.getPath(), { changeFocus })

  moveSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry
    oldPath = entry.getPath()

    dialog = new Dialog
      prompt: "Enter the new path for the file:"
      path: @rootView.project.relativize(oldPath)
      select: true
      onConfirm: (newPath) =>
        newPath = @rootView.project.resolve(newPath)
        directoryPath = fs.directory(newPath)
        try
          fs.makeTree(directoryPath) unless fs.exists(directoryPath)
          fs.move(oldPath, newPath)
          dialog.close()
        catch e
          dialog.showError("Error: " + e.message + " Try a different path:")

    @rootView.append(dialog)

  removeSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry

    entryType = if entry instanceof DirectoryView then "directory" else "file"
    atom.confirm(
      "Are you sure you would like to delete the selected #{entryType}?",
      "You are deleting #{entry.getPath()}",
      "Move to Trash", (=> Native.moveToTrash(entry.getPath())),
      "Cancel", null
      "Delete", (=> fs.remove(entry.getPath()))
    )

  add: ->
    selectedPath = @selectedEntry().getPath()
    directoryPath = if fs.isFile(selectedPath) then fs.directory(selectedPath) else selectedPath
    relativeDirectoryPath = @rootView.project.relativize(directoryPath)
    relativeDirectoryPath += '/' if relativeDirectoryPath.length > 0

    dialog = new Dialog
      prompt: "Enter the path for the new file/directory. Directories end with '/':"
      path: relativeDirectoryPath
      select: false
      onConfirm: (relativePath) =>
        endsWithDirectorySeparator = /\/$/.test(relativePath)
        path = @rootView.project.resolve(relativePath)
        try
          if fs.exists(path)
            pathType = if fs.isFile(path) then "file" else "directory"
            dialog.showError("Error: A #{pathType} already exists at path '#{path}'. Try a different path:")
          else if endsWithDirectorySeparator
            fs.makeTree(path)
            dialog.cancel()
            @entryForPath(path).buildEntries()
            @selectEntryForPath(path)
          else
            fs.write(path, "")
            @rootView.open(path)
            dialog.close()
        catch e
          dialog.showError("Error: " + e.message + " Try a different path:")

    @rootView.append(dialog)

  selectedEntry: ->
    @find('.selected')?.view()

  selectEntry: (entry) ->
    return false unless entry.get(0)
    entry = entry.view() unless entry instanceof View
    @selectedPath = entry.getPath()
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

  scrollToEntry: (entry) ->
    displayElement = if (entry instanceof DirectoryView) then entry.header else entry

    top = @scrollTop() + displayElement.position().top
    bottom = top + displayElement.outerHeight()

    if bottom > @scrollBottom()
      @scrollBottom(bottom)
    if top < @scrollTop()
      @scrollTop(top)
