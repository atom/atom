{View} = require 'space-pen'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @div class: 'tab', =>
      @span class: 'file-name', outlet: 'fileName'
      @span class: 'close-icon'

  initialize: (@editSession) ->
    @buffer = @editSession.buffer
    @subscribe @buffer, 'path-change', => @updateFileName()
    @subscribe @buffer, 'contents-modified', => @updateModifiedStatus()
    @subscribe @buffer, 'after-save', => @updateModifiedStatus()
    @subscribe @buffer, 'git-status-change', => @updateModifiedStatus()
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
    @fileName.text(@editSession.buffer.getBaseName() ? 'untitled')
