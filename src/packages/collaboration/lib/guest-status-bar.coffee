{$$, View} = require 'space-pen'

module.exports =
class HostStatusBar extends View
  @content: ->
    @div class: 'collaboration-status', =>
      @span outlet: 'status', type: 'button', class: 'status guest'

  initialize: (@session) ->
    @session.on 'started stopped', @update
    @update()

  update: ->
    # do stuff
