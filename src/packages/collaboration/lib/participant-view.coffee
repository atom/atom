crypto = require 'crypto'
{View} = require 'space-pen'

module.exports =
class ParticipantView extends View
  @content: ->
    @div class: 'participant', =>
      @img class: 'avatar', outlet: 'avatar'

  initialize: ({id, email}) ->
    emailMd5 = crypto.createHash('md5').update(email).digest('hex')
    @avatar.attr('src', "http://www.gravatar.com/avatar/#{emailMd5}?s=32")
