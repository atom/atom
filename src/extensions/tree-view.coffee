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
      @span '▸', class: 'disclosure-arrow', outlet: 'disclosureArrow', click: 'toggleExpansion'
      @span directory.getName() + '/', class: 'name'

  initialize: ({@directory, @isExpanded}) ->
    @expand() if @isExpanded

  buildEntries: ->
    contents = $$ -> @ol class: 'entries'
    for entry in @directory.getEntries()
      if entry instanceof Directory
        contents.append(new DirectoryView(directory: entry, isExpanded: false))
      else
        contents.append $$ -> @li entry.getName(), class: 'file'
    @append(contents)

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    @disclosureArrow.text('▾')
    @buildEntries()
    @isExpanded = true

  collapse: ->
    @disclosureArrow.text('▸')
    @find('.entries').remove()
    @isExpanded = false




