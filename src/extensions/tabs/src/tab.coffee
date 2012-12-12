{View} = require 'space-pen'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @div class: 'tab', =>
      @div class: 'file-name', outlet: 'fileName'

  initialize: (@editSession) ->
    @updateFileName()
    @editSession.on 'buffer-path-change.tab', =>
      @updateFileName()

  updateFileName: ->
    @fileName.text(@editSession.buffer.getBaseName() ? 'untitled')
