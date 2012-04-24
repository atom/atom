{View, $$} = require 'space-pen'
Directory = require 'directory'
$ = require 'jquery'

module.exports =
class TreeView extends View
  @activate: (rootView) ->
    requireStylesheet 'tree-view.css'
    rootView.prepend(new TreeView(rootView))

  @content: (rootView) ->
    @div class: 'tree-view', =>
      @subview 'root', new DirectoryView(directory: rootView.project.getRootDirectory(), isExpanded: true)

  initialize: (@rootView) ->
    @on 'click', '.entry', (e) =>
      entry = $(e.currentTarget)
      @rootView.open(entry.attr('path')) if entry.is('.file')
      @selectEntry(entry)
      false

    @on 'move-down', => @moveDown()
    @on 'tree-view:expand-directory', => @selectActiveFile()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()

  selectActiveFile: ->
    activeFilePath = @rootView.activeEditor()?.buffer.path
    @selectEntry(@find(".file[path='#{activeFilePath}']"))

  moveDown: ->
    selectedEntry = @selectedEntry()

    if selectedEntry.length
      @selectEntry(selectedEntry.next())
    else
      @selectEntry(@root)

  selectedEntry: ->
    @find('.selected')

  selectEntry: (entry) ->
    @find('.selected').removeClass('selected')
    entry.addClass('selected')

class DirectoryView extends View
  @content: ({directory, isExpanded}) ->
    @li class: 'directory entry', =>
      @div class: 'header', =>
        @span '▸', class: 'disclosure-arrow', outlet: 'disclosureArrow', click: 'toggleExpansion'
        @span directory.getName(), class: 'name'

  entries: null

  initialize: ({@directory, isExpanded}) ->
    @expand() if isExpanded

  buildEntries: ->
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
    @deserializeEntries(@entryStates) if @entryStates?
    @isExpanded = true
    @trigger 'tree-view:expand-directory'
    false

  collapse: ->
    @entryStates = @serializeEntries()
    @removeClass('expanded')
    @disclosureArrow.text('▸')
    @entries.remove()
    @entries = null
    @isExpanded = false

  serializeEntries: ->
    entryStates = {}
    @entries.find('> .directory.expanded').each ->
      view = $(this).view()
      entryStates[view.directory.getName()] = view.serializeEntries()
    entryStates

  deserializeEntries: (entryStates) ->
    for directoryName, childEntryStates of entryStates
      @entries.find("> .directory:contains('#{directoryName}')").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()
