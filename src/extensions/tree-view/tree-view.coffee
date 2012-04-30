{View, $$} = require 'space-pen'
Directory = require 'directory'
DirectoryView = require 'tree-view/directory-view'
MoveDialog = require 'tree-view/move-dialog'
AddDialog = require 'tree-view/add-dialog'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class TreeView extends View
  @activate: (rootView) ->
    requireStylesheet 'tree-view.css'
    rootView.horizontal.prepend(new TreeView(rootView))

  @content: (rootView) ->
    @div class: 'tree-view', tabindex: -1, =>
      @subview 'root', new DirectoryView(directory: rootView.project.getRootDirectory(), isExpanded: true)

  initialize: (@rootView) ->
    @on 'click', '.entry', (e) =>
      entry = $(e.currentTarget)
      @selectEntry(entry)
      @openSelectedEntry() if entry.is('.file')
      false

    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'tree-view:expand-directory', => @expandDirectory()
    @on 'tree-view:collapse-directory', => @collapseDirectory()
    @on 'tree-view:open-selected-entry', => @openSelectedEntry()
    @on 'tree-view:move', => @move()
    @on 'tree-view:add', => @add()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()

  deactivate: ->
    @root.unwatchEntries()

  selectActiveFile: ->
    activeFilePath = @rootView.activeEditor()?.buffer.path
    @selectEntry(@find(".file[path='#{activeFilePath}']"))

  moveDown: ->
    selectedEntry = @selectedEntry()
    if selectedEntry[0]
      if selectedEntry.is('.expanded.directory')
        return if @selectEntry(selectedEntry.find('.entry:first'))
      return if @selectEntry(selectedEntry.next())
      return if @selectEntry(selectedEntry.closest('.directory').next())
    else
      @selectEntry(@root)

  moveUp: ->
    selectedEntry = @selectedEntry()
    if selectedEntry[0]
      return if @selectEntry(selectedEntry.prev())
      return if @selectEntry(selectedEntry.parents('.directory').first())
    else
      @selectEntry(@find('.entry').last())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if selectedEntry.is('.directory')

  collapseDirectory: ->
    selectedEntry = @selectedEntry()
    directory = selectedEntry.closest('.expanded.directory').view()
    directory.collapse()
    @selectEntry(directory)

  openSelectedEntry: ->
    selectedEntry = @selectedEntry()
    if selectedEntry.is('.directory')
      selectedEntry.view().toggleExpansion()
    else if selectedEntry.is('.file')
      @rootView.open(selectedEntry.attr('path'))

  move: ->
    @rootView.append(new MoveDialog(@rootView.project, @selectedEntry().attr('path')))

  add: ->
    @rootView.append(new AddDialog(@rootView, @selectedEntry().attr('path')))

  selectedEntry: ->
    @find('.selected')

  selectEntry: (entry) ->
    return false unless entry[0]
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

