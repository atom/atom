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
    @buffer?.off '.tabs'
    @buffer = @editSession.buffer
    @buffer.on 'contents-modified.tabs', (e) => @updateBufferHasModifiedText(e.differsFromDisk)
    @buffer.on 'after-save.tabs', => @updateTab()
    @buffer.on 'git-status-change.tabs', => @updateTab()
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
