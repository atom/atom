Peer = require './peer'
Guid = require 'guid'
Prompt = require './prompt'
{createSite, Document} = require 'telepath'

peerJsSettings =
  host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com'
  port: 8080

wireDocumentEvents = (connection, sharedDocument) ->
  sharedDocument.outputEvents.on 'changed', (event) ->
    console.log 'sending event', event
    connection.send(event)

  connection.on 'data', (event) ->
    console.log 'receiving event', event
    sharedDocument.handleInputEvent(event)

startSession = ->
  id = Guid.create().toString()
  peer = new Peer(id, peerJsSettings)
  sharedDocument = Document.fromObject(createSite(id), {a: 1, b: 2, c: 3})
  window.doc = sharedDocument
  peer.on 'connection', (connection) ->
    connection.on 'open', ->
      console.log 'sending document', sharedDocument.serialize()
      connection.send(sharedDocument.serialize())
      wireDocumentEvents(connection, sharedDocument)
  id

joinSession = (id) ->
  siteId = Guid.create().toString()
  peer = new Peer(siteId, peerJsSettings)
  connection = peer.connect(id)
  connection.on 'open', ->
    console.log 'connection opened'
    connection.once 'data', (data) ->
      console.log 'received data', data
      sharedDocument = Document.deserialize(createSite(siteId), data)
      window.doc = sharedDocument
      console.log 'received document', sharedDocument.toObject()
      wireDocumentEvents(connection, sharedDocument)

module.exports =
  activate: ->
    rootView.command 'collaboration:start-session', ->
      pasteboard.write(startSession())

    rootView.command 'collaboration:join-session', ->
      new Prompt 'Enter a session id to join', (id) ->
        joinSession(id)
