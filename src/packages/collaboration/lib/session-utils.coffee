Peer = require './peer'
Guid = require 'guid'

module.exports =
  createPeer: ->
    id = Guid.create().toString()
    new Peer(id, host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com', port: 8080)

  connectDocument: (doc, connection) ->
    outputListener = (event) ->
      console.log 'sending event', event
      connection.send(event)
    doc.outputEvents.on('changed', outputListener)

    connection.on 'data', (event) ->
      console.log 'receiving event', event
      doc.handleInputEvent(event)

    connection.on 'close', ->
      doc.outputEvents.removeListener('changed', outputListener)
