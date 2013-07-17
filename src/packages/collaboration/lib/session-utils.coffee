Peer = require './peer'
Guid = require 'guid'

module.exports =
  createPeer: ->
    id = Guid.create().toString()
    new Peer(id, key: '0njqmaln320dlsor')

  connectDocument: (doc, connection) ->
    nextOutputEventId = 1
    outputListener = (event) ->
      event.id = nextOutputEventId++
      console.log 'sending event', event.id, event
      connection.send(event)
    doc.on('output', outputListener)

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
      doc.off('output', outputListener)

    connection.on 'error', (error) ->
      console.error 'connection error', error.stack ? error
