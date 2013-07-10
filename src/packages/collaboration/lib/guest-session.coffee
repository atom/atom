_ = require 'underscore'
telepath = require 'telepath'
{connectDocument, createPeer} = require './session-utils'

module.exports =
class GuestSession
  _.extend @prototype, require('event-emitter')

  participants: null
  peer: null

  constructor: (sessionId) ->
    @peer = createPeer()
    connection = @peer.connect(sessionId, {reliable: true, connectionId: @getId()})
    connection.on 'open', =>
      console.log 'connection opened'
      connection.once 'data', (data) =>
        console.log 'received document'
        doc = telepath.Document.deserialize(telepath.createSite(@getId()), data)
        atom.windowState = doc.get('windowState')
        @participants = doc.get('participants')
        connectDocument(doc, connection)

        @trigger 'started'

        @participants.push
          id: @getId()
          email: git.getConfigValue('user.email')

  getId: -> @peer.id
