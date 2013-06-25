Peer = require './peer'
Guid = require 'guid'
Prompt = require './prompt'
{createSite, Document} = require 'telepath'
$ = require 'jquery'

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
  peer.on 'connection', (connection) ->
    connection.on 'open', ->
      console.log 'sending document', atom.getWindowState().serialize()
      connection.send(atom.getWindowState().serialize())
      wireDocumentEvents(connection, atom.getWindowState())
  id

joinSession = (id) ->
  siteId = Guid.create().toString()
  peer = new Peer(siteId, peerJsSettings)
  connection = peer.connect(id, reliable: true)
  connection.on 'open', ->
    console.log 'connection opened'
    connection.once 'data', (data) ->
      console.log 'received data', data
      remoteWindowState = Document.deserialize(createSite(siteId), data)
      window.remoteWindowState = remoteWindowState
      wireDocumentEvents(connection, remoteWindowState)
      rootView.remove()
      window.rootView = deserialize(remoteWindowState.get('rootView'))
      $('body').append(rootView)

module.exports =
  activate: ->
    sessionId = null

    rootView.command 'collaboration:copy-session-id', ->
      pasteboart.write(sessionId) if sessionId

    rootView.command 'collaboration:start-session', ->
      if sessionId = startSession()
        pasteboard.write(sessionId)

    rootView.command 'collaboration:join-session', ->
      new Prompt(joinSession)
