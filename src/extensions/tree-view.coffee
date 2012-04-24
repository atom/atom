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
    @on 'click', '.file', (e) =>
      clickedLi = $(e.target)
      @rootView.open(clickedLi.attr('path'))
      @find('.selected').removeClass('selected')
      clickedLi.addClass('selected')

    @on 'tree-view:expand-directory', => @selectActiveFile()
    @rootView.on 'active-editor-path-change', => @selectActiveFile()

  selectActiveFile: ->
    console.log ""
    @find('.selected').removeClass('selected')
    activeFilePath = @rootView.activeEditor()?.buffer.path
    @find(".file[path='#{activeFilePath}']").addClass('selected')

class DirectoryView extends View
  @content: ({directory, isExpanded}) ->
    @li class: 'directory', =>
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
        @entries.append $$ -> @li entry.getName(), class: 'file', path: entry.path
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
      @entries.find("> .directory:contains(#{directoryName})").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()
