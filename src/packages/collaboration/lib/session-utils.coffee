{Peer} = require '../vendor/peer.js'
Guid = require 'guid'

url = require 'url'

module.exports =
  getSessionId: (text) ->
    return null unless text

    text = text.trim()
    sessionUrl = url.parse(text)
    if sessionUrl.host is 'session'
      sessionId = sessionUrl.path.split('/')[1]
    else
      sessionId = text

    if Guid.isGuid(sessionId)
      sessionId
    else
      null

  getSessionUrl: (sessionId) -> "atom://session/#{sessionId}"

  getIceServers: ->
    stunServer = {url: "stun:54.218.196.152:3478"}
    turnServer = {url: "turn:ninefingers@54.218.196.152:3478", credential:"youhavetoberealistic"}
    iceServers: [stunServer, turnServer]

  createPeer: ->
    id = Guid.create().toString()
    key = '0njqmaln320dlsor'
    config = @getIceServers()
    new Peer(id, {key, config})

  connectDocument: (doc, connection) ->
    nextOutputEventId = 1
    outputListener = (event) ->
      return unless connection.open
      event.id = nextOutputEventId++
      console.log 'sending event', event.id, event
      connection.send(event)
    doc.on('replicate-change', outputListener)

    queuedEvents = []
    nextInputEventId = 1
    handleInputEvent = (event) ->
      console.log 'received event', event.id, event
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

    connection.on 'data', (event) ->
      if event.id is nextInputEventId
        handleInputEvent(event)
        flushQueuedEvents()
      else
        console.log 'enqueing event', event.id, event
        queuedEvents.push(event)

    connection.on 'close', ->
      doc.off('replicate-change', outputListener)

    connection.on 'error', (error) ->
      console.error 'connection error', error.stack ? error
