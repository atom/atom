crypto = require 'crypto'
{View} = require 'space-pen'

class ParticipantView extends View
  @content: ->
    @div class: 'collaboration-participant overlay floating large', =>
      @div class: 'video-container', =>
        @video autoplay: true, outlet: 'video'
        @div class: 'avatar', outlet: 'avatar'
        @div class: 'actions', =>
          @a href: '#', class: 'remove', type: 'button', outlet: 'removeButton', title: 'Remove this person'
          @a href: '#', class: 'toggle-video', type: 'button', outlet: 'toggleVideoButton', title: 'Toggle video on/off'
          @a href: '#', class: 'toggle-audio', type: 'button', outlet: 'toggleAudioButton', title: 'Toggle audio on/off'
      @div class: 'volume-container lighter', outlet: 'volumeContainer', =>
        @div class: 'volume', outlet: 'volume'

  initialize: (@session, @participant) ->
    @participant.getMediaConnection().getInboundStreamPromise().done (stream) =>
      @video[0].src = URL.createObjectURL(stream)

    @video.click =>
      @toggleClass('large')

    #emailMd5 = crypto.createHash('md5').update(@participant.email).digest('hex')
    #@avatar.css('background-image': "http://www.gravatar.com/avatar/#{emailMd5}?s=160")

    @removeButton.click @onClickRemove
    @toggleVideoButton.click @onClickToggleVideo
    @toggleAudioButton.click @onClickToggleAudio

    map = @session.getClientIdToSiteIdMap()
    @setSiteId(map.get(@participant.clientId))
    map.on 'changed', ({key}={}) =>
      @setSiteId(map.get(@participant.clientId)) if key == @participant.clientId

  setSiteId: (siteId) ->
    return unless siteId
    @volumeContainer.addClass("site-#{siteId}")
    @volume.addClass("site-#{siteId}")

  onClickRemove: =>
    false
  onClickToggleVideo: =>
    @toggleVideoButton.toggleClass('disabled')
    @toggleClass('hide-video')
    false

  onClickToggleAudio: =>
    @toggleAudioButton.toggleClass('disabled')
    @toggleClass('hide-audio')
    false

class ParticipantViewContainer extends View
  @content: ->
    @div class: 'collaboration-participant-container'

  initialize: ->
    @participantViews = {}

  add: (session, participant) ->
    view = new ParticipantView(session, participant)
    @participantViews[participant.clientId] = view
    @append(view)

  remove: (participant) ->
    @participantViews[participant.clientId].remove()

  attach: ->
    rootView.append(this)
    this

module.exports = {ParticipantView, ParticipantViewContainer}