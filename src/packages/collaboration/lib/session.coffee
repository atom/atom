_ = require 'underscore'
keytar = require 'keytar'

WsChannel = require './ws-channel'

module.exports =
class Session
  _.extend @prototype, require('event-emitter')

  subscribe: (channelName) ->
    console.log "subscribing", channelName
    new WsChannel(channelName)

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
