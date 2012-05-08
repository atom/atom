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
      @treeView = TreeView.deserialize(state, rootView)
    else
      @treeView = new TreeView(rootView)

    rootView.horizontal.prepend(@treeView)

  @serialize: ->
    @treeView.serialize()

  @content: (rootView) ->
    @div class: 'tree-view', tabindex: -1, =>
      if rootView.project.getRootDirectory()
        @subview 'root', new DirectoryView(directory: rootView.project.getRootDirectory(), isExpanded: true)

  @deserialize: (state, rootView) ->
    treeView = new TreeView(rootView)
    treeView.root.deserializeEntryExpansionStates(state.directoryExpansionStates)
    treeView.selectEntryForPath(state.selectedPath)
    treeView.focusAfterAttach = state.hasFocus
    treeView

  root: null
  focusAfterAttach: false

  initialize: (@rootView) ->
    @on 'click', '.entry', (e) => @entryClicked(e)
    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'tree-view:expand-directory', => @expandDirectory()
    @on 'tree-view:collapse-directory', => @collapseDirectory()
    @on 'tree-view:open-selected-entry', => @openSelectedEntry()
    @on 'tree-view:move', => @moveSelectedEntry()
    @on 'tree-view:add', => @add()
    @on 'tree-view:remove', => @removeSelectedEntry()
    @on 'tree-view:directory-modified', => @selectActiveFile()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()
    @rootView.project.on 'path-change', => @updateRoot()

    @on 'tree-view:unfocus', => @rootView.activeEditor()?.focus()
    @rootView.on 'tree-view:focus', => this.focus()

  afterAttach: (onDom) ->
    @focus() if @focusAfterAttach

  serialize: ->
    directoryExpansionStates: @root.serializeEntryExpansionStates()
    selectedPath: @selectedEntry()?.getPath()
    hasFocus: @is(':focus')

  deactivate: ->
    @root?.unwatchEntries()

  entryClicked: (e) ->
    entry = $(e.currentTarget).view()
    switch e.originalEvent?.detail ? 1
      when 1
        @selectEntry(entry)
        @openSelectedEntry() if (entry instanceof FileView)
      when 2
        if entry.is('.selected.file')
          @rootView.activeEditor().focus()
        else if entry.is('.selected.directory')
          entry.toggleExpansion()

    false

  updateRoot: ->
    @root?.remove()
    @root = new DirectoryView(directory: @rootView.project.getRootDirectory(), isExpanded: true)
    @append(@root)

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
        @selectEntry(selectedEntry.find('.entry:first'))
      else
        if not @selectEntry(selectedEntry.next())
          @selectEntry(selectedEntry.closest('.directory').next())
    else
      @selectEntry(@root)

    @scollToEntry(@selectedEntry())

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

    @scollToEntry(@selectedEntry())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if (selectedEntry instanceof DirectoryView)

  collapseDirectory: ->
    selectedEntry = @selectedEntry()
    if directory = selectedEntry.closest('.expanded.directory').view()
      directory.collapse()
      @selectEntry(directory)

  openSelectedEntry: ->
    selectedEntry = @selectedEntry()
    if (selectedEntry instanceof DirectoryView)
      selectedEntry.view().toggleExpansion()
    else if (selectedEntry instanceof FileView)
      @rootView.open(selectedEntry.getPath(), false)

  moveSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry
    oldPath = @selectedEntry().getPath()

    dialog = new Dialog
      prompt: "Enter the new path for the file:"
      path: @rootView.project.relativize(oldPath)
      select: true
      onConfirm: (newPath) =>
        newPath = @rootView.project.resolve(newPath)
        directoryPath = fs.directory(newPath)
        try
          fs.makeDirectory(directoryPath) unless fs.exists(directoryPath)
          fs.move(oldPath, newPath)
        catch e
          dialog.showError("Error: " + e.message + " Try a different path:")
          return false

    @rootView.append(dialog)

  removeSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry

    entryType = if entry instanceof DirectoryView then "directory" else "file"
    message = "Are you sure you would like to delete the selected #{entryType}?"
    detailedMessage = "You are delteing #{entry.getPath()}"
    buttons = [
      ["Move to Trash", => Native.moveToTrash(entry.getPath())]
      ["Cancel", => ] # Do Nothing
      ["Delete", => fs.remove(entry.getPath())]
    ]

    Native.alert message, detailedMessage, buttons

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
        endsWithDirectorySeperator = /\/$/.test(relativePath)
        path = @rootView.project.resolve(relativePath)
        if endsWithDirectorySeperator
          fs.makeDirectory(path)
        else
          fs.write(path, "")
          @rootView.open(path)

    @rootView.append(dialog)

  selectedEntry: ->
    @find('.selected')?.view()

  selectEntry: (entry) ->
    return false unless entry.get(0)
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

  scollToEntry: (entry) ->
    displayElement = if (entry instanceof DirectoryView) then entry.header else entry

    top = @scrollTop() + displayElement.position().top
    bottom = top + displayElement.outerHeight()

    if bottom > @scrollBottom()
      @scrollBottom(bottom)
    if top < @scrollTop()
      @scrollTop(top)
