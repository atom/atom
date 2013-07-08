keytar = require 'keytar'
_ = require 'underscore'
Pusher = require '../vendor/pusher.js'

availablePeople = {}

module.exports =
  getAvailablePeople: -> _.values(availablePeople)

  advertisePresence: ->
    token = keytar.getPassword('github.com', 'github')
    return unless token

    pusher = new Pusher '490be67c75616316d386',
      encrypted: true
      authEndpoint: 'https://fierce-caverns-8387.herokuapp.com/pusher/auth'
      auth:
        params:
          oauth_token: token
    channel = pusher.subscribe('presence-atom')
    channel.bind 'pusher:subscription_succeeded', (members) ->
      console.log 'subscribed to presence channel'
      event = id: members.me.id
      event.state = {}
      if git?
        event.state.repository =
          branch: git.getShortHead()
          url: git.getConfigValue('remote.origin.url')
      channel.trigger('client-state-changed', event)

      # List self as available for debugging UI when no one else is around
      self =
        id: members.me.id
        user: members.me.info
        state: event.state
      availablePeople[self.id] = self

    channel.bind 'pusher:member_added', (member) ->
      console.log 'member added', member
      availablePeople[member.id] = {user: member.info}

    channel.bind 'pusher:member_removed', (member) ->
      console.log 'member removed', member
      availablePeople.delete(member.id)

    channel.bind 'client-state-changed', (event) ->
      console.log 'client state changed', event
      if person = availablePeople[event.id]
        person.state = event.state
