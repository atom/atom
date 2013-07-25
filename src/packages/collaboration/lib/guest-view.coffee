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
    @guestSession.on 'participant-entered participant-exited', =>
      @updateParticipants()

    @guestSession.waitForStream (stream) =>
      @video[0].src = URL.createObjectURL(stream)

    @updateParticipants()

    @attach()

  updateParticipants: ->
    @participants.empty()
    for participant in @guestSession.getOtherParticipants()
      @participants.append(new ParticipantView(participant))

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
