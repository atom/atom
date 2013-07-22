{$$, View} = require 'space-pen'
ParticipantView = require './participant-view'

module.exports =
class GuestView extends View
  @content: ->
    @div class: 'collaboration', tabindex: -1, =>
      @div class: 'guest'
      @video autoplay: true, outlet: 'video'
      @div outlet: 'participants'

  guestSession: null

  initialize: (@guestSession) ->
    @guestSession.on 'participants-changed', (participants) =>
      @updateParticipants(participants)

    @updateParticipants(@guestSession.participants.toObject())

    @addStream(@guestSession.stream)
    @guestSession.on 'stream-ready', (stream) =>
      console.log "Stream is ready", stream
      @addStream(stream)

    @attach()

  addStream: (stream) ->
    return unless stream
    @video[0].src = URL.createObjectURL(stream)

  updateParticipants: (participants) ->
    @participants.empty()
    guestId = @guestSession.getId()
    for participant in participants when participant.id isnt guestId
      @participants.append(new ParticipantView(participant))

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
