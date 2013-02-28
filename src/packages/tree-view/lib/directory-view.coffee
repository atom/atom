{View, $$} = require 'space-pen'
FileView = require './file-view'
Directory = require 'directory'
$ = require 'jquery'
Git = require 'git'

module.exports =
class DirectoryView extends View
  @content: ({directory, isExpanded} = {}) ->
    @li class: 'directory entry', =>
      @div outlet: 'header', class: 'header', =>
        @span class: 'disclosure-arrow', outlet: 'disclosureArrow'
        @span directory.getBaseName(), class: 'name', outlet: 'directoryName'
      @span "", class: 'highlight'

  directory: null
  entries: null
  header: null
  project: null

  initialize: ({@directory, isExpanded, @project, parent} = {}) ->
    @expand() if isExpanded
    @disclosureArrow.on 'click', => @toggleExpansion()

    iconClass = 'directory-icon'
    if git?
      path = @directory.getPath()
      if parent
        if git.isSubmodule(path)
          iconClass = 'submodule-icon'
        else
          @subscribe git, 'status-changed', (path, status) =>
            @updateStatus() if path.substring("#{@getPath()}/") is 0
          @subscribe git, 'statuses-changed', =>
            @updateStatus()
          @updateStatus()
      else
        iconClass = 'repository-icon' if path is git.getWorkingDirectory()

    @directoryName.addClass(iconClass)

  updateStatus: ->
    @removeClass('ignored modified new')
    path = @directory.getPath()
    if git.isPathIgnored(path)
      @addClass('ignored')
    else
      status = git.getDirectoryStatus(path)
      if git.isStatusModified(status)
        @addClass('modified')
      else if git.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @directory.path

  isPathIgnored: (path) ->
    config.get("core.hideGitIgnoredFiles") and git?.isPathIgnored(path)

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries'
    for entry in @directory.getEntries()
      continue if @isPathIgnored(entry.path)
      if entry instanceof Directory
        @entries.append(new DirectoryView(directory: entry, isExpanded: false, project: @project, parent: @directory))
      else
        @entries.append(new FileView(file: entry, project: @project))
    @append(@entries)

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded')
    @buildEntries()
    @watchEntries()
    @deserializeEntryExpansionStates(@entryStates) if @entryStates?
    @isExpanded = true
    false

  collapse: ->
    @entryStates = @serializeEntryExpansionStates()
    @removeClass('expanded')
    @unwatchEntries()
    @entries.remove()
    @entries = null
    @isExpanded = false

  watchEntries: ->
    @directory.on "contents-changed.tree-view", =>
      @buildEntries()
      @trigger "tree-view:directory-modified"

  unwatchEntries: ->
    @unwatchDescendantEntries()
    @directory.off ".tree-view"

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
