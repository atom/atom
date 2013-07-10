{$$, View} = require 'space-pen'

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
    for {email, id} in participants when id isnt @guestSession.getId()
      @participants.append $$ ->
        @div email

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
