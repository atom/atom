{View, $$} = require 'space-pen'
ScrollView = require 'scroll-view'
Directory = require 'directory'
DirectoryView = require './directory-view'
FileView = require './file-view'
Dialog = require './dialog'
fs = require 'fs'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class TreeView extends ScrollView
  @content: (rootView) ->
    @div class: 'tree-view-wrapper', =>
      @ol class: 'tree-view tool-panel', tabindex: -1, outlet: 'treeViewList'
      @div class: 'tree-view-resizer', outlet: 'resizer'

  root: null
  focusAfterAttach: false
  scrollTopAfterAttach: -1
  selectedPath: null

  initialize: (state) ->
    super
    @on 'click', '.entry', (e) => @entryClicked(e)
    @on 'mousedown', '.tree-view-resizer', (e) => @resizeStarted(e)
    @command 'core:move-up', => @moveUp()
    @command 'core:move-down', => @moveDown()
    @command 'core:close', => @detach(); false
    @command 'tree-view:expand-directory', => @expandDirectory()
    @command 'tree-view:collapse-directory', => @collapseDirectory()
    @command 'tree-view:open-selected-entry', => @openSelectedEntry(true)
    @command 'tree-view:move', => @moveSelectedEntry()
    @command 'tree-view:add', => @add()
    @command 'tree-view:remove', => @removeSelectedEntry()
    @command 'tool-panel:unfocus', => rootView.focus()
    @command 'tree-view:directory-modified', =>
      if @hasFocus()
        @selectEntryForPath(@selectedPath) if @selectedPath
      else
        @selectActiveFile()

    rootView.on 'pane:active-item-changed pane:became-active', => @selectActiveFile()
    project.on 'path-changed', => @updateRoot()
    @observeConfig 'core.hideGitIgnoredFiles', => @updateRoot()

    if @root
      @selectEntry(@root)
      @root.deserializeEntryExpansionStates(state.directoryExpansionStates)
    @selectEntryForPath(state.selectedPath) if state.selectedPath
    @focusAfterAttach = state.hasFocus
    @scrollTopAfterAttach = state.scrollTop if state.scrollTop
    @width(state.width) if state.width
    @attach() if state.attached

  afterAttach: (onDom) ->
    @focus() if @focusAfterAttach
    @scrollTop(@scrollTopAfterAttach) if @scrollTopAfterAttach > 0

  serialize: ->
    directoryExpansionStates: @root?.serializeEntryExpansionStates()
    selectedPath: @selectedEntry()?.getPath()
    hasFocus: @hasFocus()
    attached: @hasParent()
    scrollTop: @scrollTop()
    width: @width()

  deactivate: ->
    @root?.unwatchEntries()

  toggle: ->
    if @hasFocus()
      @detach()
    else
      @attach() unless @hasParent()
      @focus()

  attach: ->
    return unless project.getPath()
    rootView.horizontal.prepend(this)

  detach: ->
    @scrollTopAfterAttach = @scrollTop()
    super
    rootView.focus()

  focus: ->
    @treeViewList.focus()

  hasFocus: ->
    @treeViewList.is(':focus')

  entryClicked: (e) ->
    entry = $(e.currentTarget).view()
    switch e.originalEvent?.detail ? 1
      when 1
        @selectEntry(entry)
        @openSelectedEntry(false) if entry instanceof FileView
      when 2
        if entry.is('.selected.file')
          rootView.getActiveView().focus()
        else if entry.is('.selected.directory')
          entry.toggleExpansion()

    false

  resizeStarted: (e) =>
    $(document.body).on('mousemove', @resizeTreeView)
    $(document.body).on('mouseup', @resizeStopped)
    @css(overflow: 'hidden')

  resizeStopped: (e) =>
    $(document.body).off('mousemove', @resizeTreeView)
    $(document.body).off('mouseup', @resizeStopped)
    @css(overflow: 'auto')

  resizeTreeView: (e) =>
    @css(width: e.pageX)

  updateRoot: ->
    @root?.remove()

    if rootDirectory = project.getRootDirectory()
      @root = new DirectoryView(directory: rootDirectory, isExpanded: true, project: project)
      @treeViewList.append(@root)
    else
      @root = null

  selectActiveFile: ->
    if activeFilePath = rootView.getActiveView()?.getPath?()
      @selectEntryForPath(activeFilePath)
    else
      @deselect()

  revealActiveFile: ->
    @attach()
    @focus()

    return unless activeFilePath = rootView.getActiveView()?.getPath()

    activePathComponents = project.relativize(activeFilePath).split('/')
    currentPath = project.getPath().replace(/\/$/, '')
    for pathComponent in activePathComponents
      currentPath += '/' + pathComponent
      entry = @entryForPath(currentPath)
      if entry.hasClass('directory')
        entry.expand()
      else
        @selectEntry(entry)
        @scrollToEntry(entry)

  entryForPath: (path) ->
    fn = (bestMatchEntry, element) ->
      entry = $(element).view()
      regex = new RegExp("^" + _.escapeRegExp(entry.getPath()))
      if regex.test(path) and entry.getPath().length > bestMatchEntry.getPath().length
        entry
      else
        bestMatchEntry

    @treeViewList.find(".entry").toArray().reduce(fn, @root)

  selectEntryForPath: (path) ->
    @selectEntry(@entryForPath(path))

  moveDown: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if selectedEntry.is('.expanded.directory')
        return if @selectEntry(selectedEntry.find('.entry:first'))
      until @selectEntry(selectedEntry.next('.entry'))
        selectedEntry = selectedEntry.parents('.entry:first')
        break unless selectedEntry.length
    else
      @selectEntry(@root)

    @scrollToEntry(@selectedEntry())

  moveUp: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if previousEntry = @selectEntry(selectedEntry.prev('.entry'))
        if previousEntry.is('.expanded.directory')
          @selectEntry(previousEntry.find('.entry:last'))
      else
        @selectEntry(selectedEntry.parents('.directory').first())
    else
      @selectEntry(@treeViewList.find('.entry').last())

    @scrollToEntry(@selectedEntry())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if selectedEntry instanceof DirectoryView

  collapseDirectory: ->
    selectedEntry = @selectedEntry()
    if directory = selectedEntry.closest('.expanded.directory').view()
      directory.collapse()
      @selectEntry(directory)

  openSelectedEntry: (changeFocus) ->
    selectedEntry = @selectedEntry()
    if selectedEntry instanceof DirectoryView
      selectedEntry.view().toggleExpansion()
    else if selectedEntry instanceof FileView
      rootView.open(selectedEntry.getPath(), { changeFocus })

  moveSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry and entry isnt @root
    oldPath = entry.getPath()
    if entry instanceof FileView
      prompt = "Enter the new path for the file."
    else
      prompt = "Enter the new path for the directory."

    dialog = new Dialog
      prompt: prompt
      path: project.relativize(oldPath)
      select: true
      iconClass: 'move'
      onConfirm: (newPath) =>
        newPath = project.resolve(newPath)
        directoryPath = fs.directory(newPath)
        try
          fs.makeTree(directoryPath) unless fs.exists(directoryPath)
          fs.move(oldPath, newPath)
          dialog.close()
        catch e
          dialog.showError("Error: #{e.message} Try a different path.")

    rootView.append(dialog)

  removeSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry

    entryType = if entry instanceof DirectoryView then "directory" else "file"
    atom.confirm(
      "Are you sure you would like to delete the selected #{entryType}?",
      "You are deleting #{entry.getPath()}",
      "Move to Trash", (=> $native.moveToTrash(entry.getPath())),
      "Cancel", null
      "Delete", (=> fs.remove(entry.getPath()))
    )

  add: ->
    selectedEntry = @selectedEntry() or @root
    selectedPath = selectedEntry.getPath()
    directoryPath = if fs.isFile(selectedPath) then fs.directory(selectedPath) else selectedPath
    relativeDirectoryPath = project.relativize(directoryPath)
    relativeDirectoryPath += '/' if relativeDirectoryPath.length > 0

    dialog = new Dialog
      prompt: "Enter the path for the new file/directory. Directories end with a '/'."
      path: relativeDirectoryPath
      select: false
      iconClass: 'add-directory'

      onConfirm: (relativePath) =>
        endsWithDirectorySeparator = /\/$/.test(relativePath)
        path = project.resolve(relativePath)
        try
          if fs.exists(path)
            pathType = if fs.isFile(path) then "file" else "directory"
            dialog.showError("Error: A #{pathType} already exists at path '#{path}'. Try a different path.")
          else if endsWithDirectorySeparator
            fs.makeTree(path)
            dialog.cancel()
            @entryForPath(path).buildEntries()
            @selectEntryForPath(path)
          else
            fs.write(path, "")
            rootView.open(path)
            dialog.close()
        catch e
          dialog.showError("Error: #{e.message} Try a different path.")

    dialog.miniEditor.getBuffer().on 'changed', =>
      if /\/$/.test(dialog.miniEditor.getText())
        dialog.prompt.removeClass('add-file').addClass('add-directory')
      else
        dialog.prompt.removeClass('add-directory').addClass('add-file')

    rootView.append(dialog)

  selectedEntry: ->
    @treeViewList.find('.selected')?.view()

  selectEntry: (entry) ->
    return false unless entry.get(0)
    entry = entry.view() unless entry instanceof View
    @selectedPath = entry.getPath()
    @deselect()
    entry.addClass('selected')

  deselect: ->
    @treeViewList.find('.selected').removeClass('selected')

  scrollTop: (top) ->
    if top
      @treeViewList.scrollTop(top)
    else
      @treeViewList.scrollTop()

  scrollBottom: (bottom) ->
    if bottom
      @treeViewList.scrollBottom(bottom)
    else
      @treeViewList.scrollBottom()

  scrollToEntry: (entry) ->
    displayElement = if entry instanceof DirectoryView then entry.header else entry
    top = @scrollTop() + displayElement.position().top
    bottom = top + displayElement.outerHeight()
    if bottom > @scrollBottom()
      @treeViewList.scrollBottom(bottom)
    if top < @scrollTop()
      @treeViewList.scrollTop(top)

  scrollToBottom: ->
    super()

    @selectEntry(@root.find('.entry:last')) if @root
    @scrollToEntry(@root.find('.entry:last')) if @root

  scrollToTop: ->
    super()
    @selectEntry(@root) if @root
    @treeViewList.scrollTop(0)
