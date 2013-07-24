{$$, View} = require 'space-pen'
ParticipantView = require './participant-view'

module.exports =
class GuestView extends View
  @content: ->
    @div class: 'collaboration', tabindex: -1, =>
      @div class: 'guest'
      @div outlet: 'participants'

  guestSession: null

  initialize: (@guestSession) ->
    @guestSession.on 'participants-changed', (participants) =>
      @updateParticipants(participants)

    @updateParticipants(@guestSession.participants.toObject())

    @attach()

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
