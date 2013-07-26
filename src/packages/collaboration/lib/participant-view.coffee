crypto = require 'crypto'
{View} = require 'space-pen'

module.exports =
class ParticipantView extends View
  @content: ->
  	@div class: 'collaboration-participant overlay floating large', =>
  	  @div class: 'video-container', =>
  	    @video autoplay: true, outlet: 'video'
  	    @div class: 'actions', =>
  	      @a href: '#', class: 'remove', type: 'button', outlet: 'removeButton', title: 'Remove this person'
  	      @a href: '#', class: 'toggle-video', type: 'button', outlet: 'toggleVideoButton', title: 'Toggle video on/off'
  	      @a href: '#', class: 'toggle-audio', type: 'button', outlet: 'toggleAudioButton', title: 'Toggle audio on/off'
      @div class: 'volume-container', outlet: 'volumeContainer', =>
      	@div class: 'volume', outlet: 'volume'

  initialize: (@session, @participant) ->
    {id, email} = @participant.getState()

    @session.waitForStream (stream) =>
      @video[0].src = URL.createObjectURL(stream)

    @video.click =>
      @toggleClass('large')

    @removeButton.click @onClickRemove
    @toggleVideoButton.click @onClickToggleVideo
    @toggleAudioButton.click @onClickToggleAudio

    # @attr('title', email)
    # emailMd5 = crypto.createHash('md5').update(email).digest('hex')
    # @avatar.attr('src', "http://www.gravatar.com/avatar/#{emailMd5}?s=32")

  attach: ->
    rootView.append(this)

  onClickRemove: =>
  	false
  onClickToggleVideo: =>
  	false
  onClickToggleAudio: =>
  	false
