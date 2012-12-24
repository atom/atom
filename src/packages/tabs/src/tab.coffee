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

  updateFileName: ->
    @fileName.text(@editSession.buffer.getBaseName() ? 'untitled')
