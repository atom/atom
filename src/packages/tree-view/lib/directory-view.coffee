{View, $$} = require 'space-pen'
FileView = require './file-view'
Directory = require 'directory'
$ = require 'jquery'
fs = require 'fs'

module.exports =
class DirectoryView extends View
  @content: ({directory, isExpanded} = {}) ->
    @li class: 'directory entry', =>
      @span class: 'highlight'
      @div outlet: 'header', class: 'header', =>
        @span class: 'disclosure-arrow', outlet: 'disclosureArrow'
        @span directory.getBaseName(), class: 'name', outlet: 'directoryName'

  directory: null
  entries: null
  header: null
  project: null

  initialize: ({@directory, isExpanded, @project, parent} = {}) ->
    @expand() if isExpanded
    @disclosureArrow.on 'click', => @toggleExpansion()

    iconClass = 'directory-icon'
    repo = project.getRepo()
    if repo?
      path = @directory.getPath()
      if parent
        if repo.isSubmodule(path)
          iconClass = 'submodule-icon'
        else
          @subscribe repo, 'status-changed', (path, status) =>
            @updateStatus() if path.indexOf("#{@getPath()}/") is 0
          @subscribe repo, 'statuses-changed', =>
            @updateStatus()
          @updateStatus()
      else
        iconClass = 'repository-icon' if @isRepositoryRoot()

    @directoryName.addClass(iconClass)

  updateStatus: ->
    @removeClass('ignored modified new')
    path = @directory.getPath()
    repo = project.getRepo()
    if repo.isPathIgnored(path)
      @addClass('ignored')
    else
      status = repo.getDirectoryStatus(path)
      if repo.isStatusModified(status)
        @addClass('modified')
      else if repo.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @directory.path

  isRepositoryRoot: ->
    try
      repo = project.getRepo()
      repo? and repo.getWorkingDirectory() is fs.realpathSync(@getPath())
    catch e
      false

  isPathIgnored: (path) ->
    config.get("core.hideGitIgnoredFiles") and project.getRepo()?.isPathIgnored(path)

  buildEntries: ->
    @unwatchDescendantEntries()
    @entries?.remove()
    @entries = $$ -> @ol class: 'entries list-unstyled'
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
