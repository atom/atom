ScrollView = require 'scroll-view'
archive = require 'ls-archive'
FileView = require './file-view'
DirectoryView = require './directory-view'
fs = require 'fs'
humanize = require 'humanize-plus'

module.exports =
class ArchiveView extends ScrollView
  @content: ->
    @div class: 'archive-view', tabindex: -1, =>
      @div class: 'archive-container', =>
        @div outlet: 'loadingMessage', class: 'loading-message', 'Loading archive\u2026'
        @div outlet: 'summary', class: 'summary'
        @div outlet: 'tree', class: 'archive-tree'

  initialize: (editSession) ->
    super

    @setModel(editSession)

  setPath: (path) ->
    return unless path?
    return if @path is path

    @path = path
    @summary.hide()
    @tree.hide()
    @loadingMessage.show()
    archive.list @path, tree: true, (error, entries) =>
      return unless path is @path

      if error?
        console.error("Error listing archive file: #{@path}", error.stack ? error)
      else
        @loadingMessage.hide()
        @createTreeEntries(entries)
        @updateSummary()

  createTreeEntries: (entries) ->
    @tree.empty()

    for entry in entries
      if entry.isDirectory()
        @tree.append(new DirectoryView(@path, entry))
      else
        @tree.append(new FileView(@path, entry))

    @tree.show()
    @tree.find('.file').view()?.select()

  updateSummary: ->
    fileCount = @tree.find('.file').length
    fileLabel = if fileCount is 1 then "1 file" else "#{humanize.intcomma(fileCount)} files"

    directoryCount = @tree.find('.directory').length
    directoryLabel = if directoryCount is 1 then "1 folder" else "#{humanize.intcomma(directoryCount)} folders"

    @summary.text("#{humanize.filesize(fs.statSync(@path).size)} with #{fileLabel} and #{directoryLabel}").show()

  focusSelectedFile: ->
    @tree.find('.selected').view()?.focus()

  focus: ->
    @focusSelectedFile()

  setModel: (editSession) ->
    @setPath(editSession?.getPath())
