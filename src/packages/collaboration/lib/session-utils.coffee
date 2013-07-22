Peer = require '../vendor/peer.js'
Guid = require 'guid'

module.exports =
  createPeer: ->
    id = Guid.create().toString()
    new Peer(id, host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com', port: 8080)

  connectDocument: (doc, connection) ->
    nextOutputEventId = 1
    outputListener = (event) ->
      event.id = nextOutputEventId++
      console.log 'sending event', event.id, event
      connection.send(event)
    doc.outputEvents.on('changed', outputListener)

    queuedEvents = []
    nextInputEventId = 1
    handleInputEvent = (event) ->
      console.log 'received event', event.id, event
      doc.handleInputEvent(event)
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

    connection.on 'data', (event) ->
      if event.id is nextInputEventId
        handleInputEvent(event)
        flushQueuedEvents()
      else
        console.log 'enqueing event', event.id, event
        queuedEvents.push(event)

    connection.on 'close', ->
      doc.outputEvents.removeListener('changed', outputListener)

    connection.on 'error', (error) ->
      console.error 'connection error', error.stack ? error
