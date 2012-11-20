{View} = require 'space-pen'

module.exports =
class Tab extends View
  @content: (editSession) ->
    @div class: 'tab', =>
      @div editSession.buffer.getBaseName(), class: 'file-name', outlet: 'fileName'

  initialize: (@editSession) ->
    @editSession.on 'buffer-path-change.tab', =>
      @fileName.text(@editSession.buffer.getBaseName())
