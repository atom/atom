{View, $$} = require 'space-pen'
Directory = require 'directory'
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

  selectedEntry: ->
    @find('.selected')

  selectEntry: (entry) ->
    return false unless entry[0]
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

class DirectoryView extends View
  @content: ({directory, isExpanded}) ->
    @li class: 'directory entry', =>
      @div class: 'header', =>
        @span '▸', class: 'disclosure-arrow', outlet: 'disclosureArrow'
        @span directory.getName(), class: 'name'

  entries: null

  initialize: ({@directory, isExpanded}) ->
    @expand() if isExpanded
    @disclosureArrow.on 'click', => @toggleExpansion()

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries'
    for entry in @directory.getEntries()
      if entry instanceof Directory
        @entries.append(new DirectoryView(directory: entry, isExpanded: false))
      else
        @entries.append $$ -> @li entry.getName(), class: 'file entry', path: entry.path
    @append(@entries)

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded')
    @disclosureArrow.text('▾')
    @buildEntries()
    @watchEntries()
    @deserializeEntryExpansionStates(@entryStates) if @entryStates?
    @isExpanded = true
    false

  collapse: ->
    @entryStates = @serializeEntryExpansionStates()
    @removeClass('expanded')
    @disclosureArrow.text('▸')
    @unwatchEntries()
    @entries.remove()
    @entries = null
    @isExpanded = false

  watchEntries: ->
    @directory.on "contents-change.#{@directory.path}", =>
      @buildEntries()

  unwatchEntries: ->
    @unwatchDescendantEntries()
    @directory.off ".#{@directory.path}"

  unwatchDescendantEntries: ->
    @find('.expanded.directory').each ->
      $(this).view().unwatchEntries()

  serializeEntryExpansionStates: ->
    entryStates = {}
    @entries.find('> .directory.expanded').each ->
      view = $(this).view()
      entryStates[view.directory.getName()] = view.serializeEntryExpansionStates()
    entryStates

  deserializeEntryExpansionStates: (entryStates) ->
    for directoryName, childEntryStates of entryStates
      @entries.find("> .directory:contains('#{directoryName}')").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()

Editor = require 'editor'
fs = require 'fs'
class MoveDialog extends View
  @content: ->
    @div class: 'move-dialog', =>
      @div "Enter the new path for the file:", outlet: 'prompt'
      @subview 'editor', new Editor(mini: true)

  initialize: (@project, @path) ->
    @editor.focus()
    @on 'tree-view:confirm', => @confirm()
    @on 'tree-view:cancel', => @cancel()
    @editor.on 'focusout', => @remove()

    relativePath = @project.relativize(@path)
    @editor.setText(relativePath)
    baseName = fs.base(path)
    range = [[0, relativePath.length - baseName.length], [0, relativePath.length]]
    @editor.setSelectionBufferRange(range)

  confirm: ->
    fs.move(@path, @project.resolve(@editor.getText()))
    @remove()
    $('#root-view').focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()

