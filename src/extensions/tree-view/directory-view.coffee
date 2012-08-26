{View, $$} = require 'space-pen'
FileView = require 'tree-view/file-view'
Directory = require 'directory'
$ = require 'jquery'

module.exports =
class DirectoryView extends View
  @content: ({directory, isExpanded} = {}) ->
    @li class: 'directory entry', =>
      @div outlet: 'header', class: 'header', =>
        @span '▸', class: 'disclosure-arrow', outlet: 'disclosureArrow'
        @span directory.getBaseName(), class: 'name'

  directory: null
  entries: null
  header: null

  initialize: ({@directory, isExpanded} = {}) ->
    @expand() if isExpanded
    @disclosureArrow.on 'click', => @toggleExpansion()

  getPath: ->
    @directory.path

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries'
    for entry in @directory.getEntries()
      if entry instanceof Directory
        @entries.append(new DirectoryView(directory: entry, isExpanded: false))
      else
        @entries.append(new FileView(entry))
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
      @trigger "tree-view:directory-modified"

  unwatchEntries: ->
    @unwatchDescendantEntries()
    @directory.off ".#{@directory.path}"

  unwatchDescendantEntries: ->
    @find('.expanded.directory').each ->
      $(this).view().unwatchEntries()

  serializeEntryExpansionStates: ->
    entryStates = {}
    @entries?.find('> .directory.expanded').each ->
      view = $(this).view()
      entryStates[view.directory.getBaseName()] = view.serializeEntryExpansionStates()
    entryStates

  deserializeEntryExpansionStates: (entryStates) ->
    for directoryName, childEntryStates of entryStates
      @entries.find("> .directory:contains('#{directoryName}')").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()

