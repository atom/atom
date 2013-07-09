url = require 'url'
{$$, View} = require 'space-pen'

module.exports =
class CollaborationView extends View
  @content: ->
    @div class: 'collaboration', tabindex: -1, =>
      @div outlet: 'share', type: 'button', class: 'share'
      @div outlet: 'participants'

  sharingSession: null

  initialize: (@sharingSession) ->
    if @sharingSession.isSharing()
      @share.addClass('running')

    @share.on 'click', =>
      @share.disable()

      if @sharingSession.isSharing()
        @sharingSession.stop()
      else
        @sharingSession.start()

    @sharingSession.on 'started stopped', =>
      @share.toggleClass('running').enable()

    @attach()

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
