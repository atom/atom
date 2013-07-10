{$$, View} = require 'space-pen'

module.exports =
class HostView extends View
  @content: ->
    @div class: 'collaboration', tabindex: -1, =>
      @div outlet: 'share', type: 'button', class: 'share'
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

    @attach()

  updateParticipants: (participants) ->
    @participants.empty()
    for {email, id} in participants when id isnt @hostSession.getId()
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
