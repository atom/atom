{View} = require 'space-pen'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @div class: 'tab', =>
      @span class: 'file-name', outlet: 'fileName'
      @span class: 'close-icon'

  initialize: (@editSession) ->
    @updateFileName()
    @editSession.on 'buffer-path-change.tab', =>
      @updateFileName()
    @subscribeToBuffer()

  updateTab: ->
    @updateBufferHasModifiedText(@buffer.isModified())

  subscribeToBuffer: ->
    @buffer = @editSession.buffer
    @subscribe @buffer, 'contents-modified.tabs', (e) => @updateBufferHasModifiedText(e.differsFromDisk)
    @subscribe @buffer, 'after-save.tabs', => @updateTab()
    @subscribe @buffer, 'git-status-change.tabs', => @updateTab()
    @updateTab()

  updateBufferHasModifiedText: (differsFromDisk) ->
    if differsFromDisk
      @toggleClass('file-modified') unless @isModified
      @isModified = true
    else
      @removeClass('file-modified') if @isModified
      @isModified = false

  updateFileName: ->
    @fileName.text(@editSession.buffer.getBaseName() ? 'untitled')
