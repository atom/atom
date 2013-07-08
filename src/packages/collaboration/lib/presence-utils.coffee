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
      availablePeople[members.me.id] = members.me
      console.log 'subscribed to presence channel'
      event = id: members.me.id
      if git?
        event.repository =
          branch: git.getShortHead()
          url: git.getConfigValue('remote.origin.url')
      channel.trigger('client-details', event)

    channel.bind 'pusher:member_added', (member) ->
      console.log 'member added', member
      availablePeople[member.id] = member

    channel.bind 'pusher:member_removed', (member) ->
      console.log 'member removed', member
      availablePeople.delete(member.id)
