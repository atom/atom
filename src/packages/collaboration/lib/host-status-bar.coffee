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

    @session.on 'listening started stopped', @update
    @update()

    #@hostSession.waitForStream (stream) =>
    #  @video[0].src = URL.createObjectURL(stream)

  update: =>
    console.log 'updating', this
    if @session.isListening()
      @status.addClass('running')
      @connections.show().text(@session.participants.length)
    else
      @status.removeClass('running')
      @connections.hide()
