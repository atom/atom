{View, $$} = require 'space-pen'
Directory = require 'directory'

module.exports =
class TreeView extends View
  @activate: (rootView) ->
    requireStylesheet 'tree-view.css'
    rootView.prepend(new TreeView(rootView.project.getRootDirectory()))

  @content: (directory) ->
    @div class: 'tree-view', =>
      @subview 'root', new DirectoryView(directory: directory, isExpanded: true)

  initialize: (@project) ->

class DirectoryView extends View
  @content: ({directory, isExpanded}) ->
    @li class: 'directory', =>
      @disclosureArrow(isExpanded)
      @span directory.getName() + '/', class: 'name'

  @disclosureArrow: (isExpanded) ->
    arrowCharacter = if isExpanded then '▾' else '▸'
    @span arrowCharacter, class: 'disclosure'

  initialize: ({@directory, @isExpanded}) ->
    @buildEntries() if @isExpanded

  buildEntries: ->
    contents = $$ -> @ol class: 'entries'
    for entry in @directory.getEntries()
      if entry instanceof Directory
        contents.append(new DirectoryView(directory: entry, isExpanded: false))
      else
        contents.append $$ -> @li entry.getName(), class: 'file'
    @append(contents)
