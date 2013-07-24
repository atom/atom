_ = require 'underscore'
keytar = require 'keytar'

RateLimitedChannel = require './rate-limited-channel'

module.exports =
class Session
  _.extend @prototype, require('event-emitter')

  subscribe: (channelName) ->
    new RateLimitedChannel(@getPusherConnection().subscribe(channelName))

  getPusherConnection: ->
    @pusher ?= new Pusher '490be67c75616316d386',
      encrypted: true
      authEndpoint: 'https://fierce-caverns-8387.herokuapp.com/pusher/auth'
      auth:
        params:
          oauth_token: keytar.getPassword('github.com', 'github')

  connectDocument: (doc, channel) ->
    nextOutputEventId = 1
    outputListener = (event) ->
      event.id = nextOutputEventId++
      console.log 'sending event', event
      channel.send('client-document-changed', event)
    doc.on('replicate-change', outputListener)

    queuedEvents = []
    nextInputEventId = 1
    handleInputEvent = (event) ->
      console.log 'received event', event
      doc.applyRemoteChange(event)
      nextInputEventId = event.id + 1
    flushQueuedEvents = ->
      loop
        eventHandled = false
        for event, index in queuedEvents when event.id is nextInputEventId
          handleInputEvent(event)
          queuedEvents.splice(index, 1)
          eventHandled = true
          break
        break unless eventHandled

    channel.on 'client-document-changed', (event) ->
      if event.id is nextInputEventId
        handleInputEvent(event)
        flushQueuedEvents()
      else
        console.log 'enqueing event', event
        queuedEvents.push(event)
