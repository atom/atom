{$$, View} = require 'space-pen'

module.exports =
class HostStatusBar extends View
  @content: ->
    @div class: 'collaboration-status', =>
      @span outlet: 'status', type: 'button', class: 'status share'
      @span outlet: 'connections', class: 'connections'

  initialize: (@session) ->
    @status.on 'click', =>
      if @session.isListening()
        @session.stop()
      else
        @session.start()

    @session.on 'listening started stopped participant-entered participant-exited', @update
    @update()

  update: =>
    if @session.isListening()
      @status.addClass('running')
      @connections.show().text(@session.participants.length)
    else
      @status.removeClass('running')
      @connections.hide()
