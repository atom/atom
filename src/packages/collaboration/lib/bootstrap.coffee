require 'atom'
require 'window'
{createPeer, connectDocument} = require './session-utils'
{createSite, Document} = require 'telepath'

window.setDimensions(x: 0, y: 0, width: 800, height: 800)
atom.show()

peer = createPeer()
{sessionId} = atom.getLoadSettings()
connection = peer.connect(sessionId, reliable: true)
connection.on 'open', ->
  console.log 'connection opened'
  connection.once 'data', (data) ->
    console.log 'received document'
    atom.windowState = Document.deserialize(createSite(peer.id), data)
    connectDocument(atom.windowState, connection)
    window.setUpEnvironment('editor')
    window.startEditorWindow()
