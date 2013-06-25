require 'atom'
require 'window'
_ = require 'underscore'

window.setDimensions(x: 0, y: 0, width: 800, height: 800)
atom.show()

Peer = require './peer'
Guid = require 'guid'
{createSite, Document} = require 'telepath'

peerJsSettings =
  host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com'
  port: 8080

wireDocumentEvents = (connection, sharedDocument) ->
  sharedDocument.outputEvents.on 'changed', (event) ->
    console.log 'sending event', event
    connection.send(event)

  connection.on 'data', (event) ->
    console.log 'receiving event', _.clone(event.targetPath)
    sharedDocument.handleInputEvent(event)

siteId = Guid.create().toString()
peer = new Peer(siteId, peerJsSettings)
{sessionId} = atom.getLoadSettings()
connection = peer.connect(sessionId, reliable: true)
connection.on 'open', ->
  console.log 'connection opened'
  connection.once 'data', (data) ->
    console.log 'received data', data
    atom.windowState = Document.deserialize(createSite(siteId), data)
    wireDocumentEvents(connection, atom.windowState)
    window.setUpEnvironment('editor')
    window.startEditorWindow()
