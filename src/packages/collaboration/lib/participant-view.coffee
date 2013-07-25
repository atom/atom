crypto = require 'crypto'
{View} = require 'space-pen'

module.exports =
class ParticipantView extends View
  @content: ->
    @div class: 'participant', =>
      @img class: 'avatar', outlet: 'avatar'

  initialize: ({id, avatar_url}) ->
    @avatar.attr('src', avatar_url)
