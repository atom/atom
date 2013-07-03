require 'atom'
require 'window'
$ = require 'jquery'
{$$} = require 'space-pen'
{createPeer, connectDocument} = require './session-utils'
{createSite, Document} = require 'telepath'

window.setDimensions(width: 350, height: 100)
window.setUpEnvironment('editor')
{sessionId} = atom.getLoadSettings()

loadingView = $$ ->
  @div style: 'margin: 10px; text-align: center', =>
    @div "Joining session #{sessionId}"
$(window.rootViewParentSelector).append(loadingView)
atom.show()

peer = createPeer()
connection = peer.connect(sessionId, reliable: true)
connection.on 'open', ->
  console.log 'connection opened'
  connection.once 'data', (data) ->
    loadingView.remove()
    console.log 'received document'
    atom.windowState = Document.deserialize(data, site: createSite(peer.id))
    connectDocument(atom.windowState, connection)
    window.startEditorWindow()
