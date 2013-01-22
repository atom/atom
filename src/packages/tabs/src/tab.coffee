{View} = require 'space-pen'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @div class: 'tab', =>
      @div class: 'left-mask', =>
        @span class: 'left-inner-mask'
      @span class: 'file-name', outlet: 'fileName'
      @span class: 'close-icon'
      @div class: 'right-mask', =>
        @span class: 'right-inner-mask'

  initialize: (@editSession) ->
    @buffer = @editSession.buffer
    @subscribe @buffer, 'path-changed', => @updateFileName()
    @subscribe @buffer, 'contents-modified', => @updateModifiedStatus()
    @subscribe @buffer, 'saved', => @updateModifiedStatus()
    @subscribe @buffer, 'git-status-changed', => @updateModifiedStatus()
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
