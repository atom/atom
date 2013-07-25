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
    @hostSession.on 'started stopped', =>
      @share.toggleClass('running').enable()

    @hostSession.on 'participant-entered participant-exited', =>
      @updateParticipants()

    @hostSession.one 'started', =>
      @updateParticipants()
      @hostSession.waitForStream (stream) =>
        @video[0].src = URL.createObjectURL(stream)

    @attach()

  updateParticipants: ->
    @participants.empty()
    for participant in @hostSession.getOtherParticipants()
      @participants.append(new ParticipantView(participant))

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
