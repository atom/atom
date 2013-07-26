crypto = require 'crypto'
{View} = require 'space-pen'

module.exports =
class ParticipantView extends View
  @content: ->
  	@div class: 'collaboration-participant overlay floating large', =>
      @video autoplay: true, outlet: 'video'
      @div class: 'volume-container', outlet: 'volumeContainer', =>
      	@div class: 'volume', outlet: 'volume'

  initialize: (@session, {id, email}) ->
  	@session.waitForStream (stream) =>
      @video[0].src = URL.createObjectURL(stream)

    @video.click =>
      @toggleClass('large')

    # emailMd5 = crypto.createHash('md5').update(email).digest('hex')
    # @avatar.attr('src', "http://www.gravatar.com/avatar/#{emailMd5}?s=32")

  attach: ->
    rootView.append(this)
