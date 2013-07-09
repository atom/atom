url = require 'url'
{$$} = require 'space-pen'
ScrollView = require 'scroll-view'
BuddyView = require './buddy-view'

module.exports =
class BuddyList extends ScrollView
  @content: ->
    @div class: 'buddy-list', tabindex: -1, =>
      @button outlet: 'shareButton', type: 'button', class: 'btn btn-default'
      @div outlet: 'buddies'

  presence: null
  sharingSession: null

  initialize: (@presence, @sharingSession) ->
    super

    if @sharingSession.isSharing()
      @shareButton.text('Stop')
    else
      @shareButton.text('Start')

    @presence.on 'person-added', => @updateBuddies()
    @presence.on 'person-removed', => @updateBuddies()
    @presence.on 'person-status-changed', => @updateBuddies()
    @shareButton.on 'click', =>
      @shareButton.disable()

      if @sharingSession.isSharing()
        @shareButton.text('Stopping...')
        @sharingSession.stop()
      else
        @shareButton.text('Starting...')
        @sharingSession.start()

    @sharingSession.on 'started', =>
      @shareButton.text('Stop').enable()

    @sharingSession.on 'stopped', =>
      @shareButton.text('Start').enable()

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    rootView.horizontal.append(this)
    @focus()
    @updateBuddies()

  updateBuddies: ->
    @buddies.empty()
    @buddies.append(new BuddyView(buddy)) for buddy in @presence.getPeople()
