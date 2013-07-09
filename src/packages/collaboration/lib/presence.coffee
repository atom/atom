guid = require 'guid'
$ = require 'jquery'
keytar = require 'keytar'
_ = require 'underscore'
Pusher = require '../vendor/pusher.js'

module.exports =
class Presence
  _.extend @prototype, require('event-emitter')

  people: null
  personId: null
  windowId: null

  constructor: ->
    @people = {}
    @windowId = guid.create().toString()
    @connect()

  connect: ->
    token = keytar.getPassword('github.com', 'github')
    return unless token

    pusher = new Pusher '490be67c75616316d386',
      encrypted: true
      authEndpoint: 'https://fierce-caverns-8387.herokuapp.com/pusher/auth'
      auth:
        params:
          oauth_token: token
    channel = pusher.subscribe('presence-atom')
    channel.bind 'pusher:subscription_succeeded', (members) =>
      console.log 'subscribed to presence channel'
      @personId = members.me.id
      event = id: @personId
      event.window = id: @windowId
      if git?
        event.window.repository =
          branch: git.getShortHead()
          url: git.getConfigValue('remote.origin.url')
      channel.trigger('client-window-opened', event)

      # List self as available for debugging UI when no one else is around
      self =
        id: @personId
        user: members.me.info
        windows: {}
      self.windows[@windowId] = event.window
      @people[self.id] = self
      @trigger 'person-status-changed', self

    channel.bind 'pusher:member_added', (member) =>
      console.log 'member added', member
      @people[member.id] = {user: member.info, windows: {}}
      @trigger 'person-added', @people[member.id]

    channel.bind 'pusher:member_removed', (member) =>
      console.log 'member removed', member
      @people.delete(member.id)
      @trigger 'person-removed'

    channel.bind 'client-window-opened', (event) =>
      console.log 'window opened', event
      if person = @people[event.id]
        person.windows[event.window.id] = event.window
      @trigger 'person-status-changed', person

    channel.bind 'client-window-closed', (event) =>
      console.log 'window closed', event
      if person = @people[event.id]
        delete person.windows[event.windowId]
        @trigger 'person-status-changed', person

    $(window).on 'beforeunload', =>
      channel.trigger 'client-window-closed', {id: @personId, @windowId}

  getPeople: -> _.values(@people)
