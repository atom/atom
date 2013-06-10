ScrollView = require 'scroll-view'
archive = require 'ls-archive'
{$$} = require 'space-pen'
FileView = require './file-view'
DirectoryView = require './directory-view'

module.exports =
class ArchiveView extends ScrollView
  @content: ->
    @div class: 'archive-view', tabindex: -1, =>
      @div class: 'archive-container', =>
        @span outlet: 'loadingMessage', class: 'loading-message', 'Loading archive\u2026'
        @div outlet: 'tree', class: 'archive-tree'

  initialize: (editSession) ->
    super

    @setModel(editSession)

  setPath: (path) ->
    return unless path?
    return if @path is path

    @path = path
    @tree.hide()
    @loadingMessage.show()
    archive.list @path, tree: true, (error, entries) =>
      if error?
        console.error("Error listing archive file: #{@path}", error.stack ? error)
      else
        @loadingMessage.hide()
        @tree.empty()

        for entry in entries
          if entry.isDirectory()
            @tree.append(new DirectoryView(@path, entry))
          else
            @tree.append(new FileView(@path, entry))

        @tree.find('.entry.file:first').addClass('selected')
        @tree.show()

  setModel: (editSession) ->
    @setPath(editSession?.getPath())
