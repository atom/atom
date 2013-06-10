{View} = require 'space-pen'
FileView = require './file-view'

module.exports =
class DirectoryView extends View
  @content: (archivePath, entry) ->
    @div class: 'entry', =>
      @span entry.getName(), class: 'directory'

  initialize: (archivePath, entry) ->
    for child in entry.children
      if child.isDirectory()
        @append(new DirectoryView(archivePath, child))
      else
        @append(new FileView(archivePath, child))
