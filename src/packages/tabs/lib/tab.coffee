{View} = require 'space-pen'
fs = require 'fs'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @li class: 'tab sortable', =>
      @span class: 'file-name', outlet: 'fileName'
      @span class: 'close-icon'

  initialize: (@editSession, @editor) ->
    @buffer = @editSession.buffer
    @subscribe @buffer, 'path-changed', => @updateFileName()
    @subscribe @buffer, 'contents-modified', => @updateModifiedStatus()
    @subscribe @buffer, 'saved', => @updateModifiedStatus()
    @subscribe @editor, 'editor:edit-session-added', => @updateFileName()
    @subscribe @editor, 'editor:edit-session-removed', => @updateFileName()
    @updateFileName()
    @updateModifiedStatus()

  updateModifiedStatus: ->
    if @buffer.isModified()
      @toggleClass('file-modified') unless @isModified
      @isModified = true
    else
      @removeClass('file-modified') if @isModified
      @isModified = false

  updateFileName: ->
    fileNameText = @editSession.buffer.getBaseName()
    if fileNameText?
      duplicates = @editor.getEditSessions().filter (session) -> fileNameText is session.buffer.getBaseName()
      if duplicates.length > 1
        directory = fs.base(fs.directory(@editSession.getPath()))
        fileNameText = "#{fileNameText} - #{directory}" if directory
    else
      fileNameText = 'untitled'

    @fileName.text(fileNameText)
    @fileName.attr('title', @editSession.getPath())
