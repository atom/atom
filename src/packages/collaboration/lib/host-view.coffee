{$$, View} = require 'space-pen'
ParticipantView = require './participant-view'

module.exports =
class HostView extends View
  @content: ->
    @div class: 'collaboration', tabindex: -1, =>
      @div outlet: 'share', type: 'button', class: 'share'
      @video autoplay: true, outlet: 'video'
      @div outlet: 'participants'

  hostSession: null

  initialize: (@hostSession) ->
    if @hostSession.isSharing()
      @share.addClass('running')

    @share.on 'click', =>
      @share.disable()

      if @hostSession.isSharing()
        @hostSession.stop()
      else
        @hostSession.start()

    @hostSession.on 'started stopped', =>
      @share.toggleClass('running').enable()

    @hostSession.on 'participants-changed', (participants) =>
      @updateParticipants(participants)

    @addStream(@hostSession.stream)
    @hostSession.on 'stream-ready', (stream) =>
      console.log "Stream is ready", stream
      @addStream(stream)

    @attach()

  addStream: (stream) ->
    return unless stream
    @video[0].src = URL.createObjectURL(stream)

  updateParticipants: (participants) ->
    @participants.empty()
    hostId = @hostSession.getId()
    for participant in participants when participant.id isnt hostId
      @participants.append(new ParticipantView(participant))

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
