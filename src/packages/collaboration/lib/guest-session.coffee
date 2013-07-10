_ = require 'underscore'
telepath = require 'telepath'
{connectDocument, createPeer} = require './session-utils'

module.exports =
class GuestSession
  _.extend @prototype, require('event-emitter')

  participants: null
  repository: null
  peer: null

  constructor: (sessionId) ->
    @peer = createPeer()
    connection = @peer.connect(sessionId, {reliable: true, connectionId: @getId()})
    connection.on 'open', =>
      console.log 'connection opened'
      connection.once 'data', (data) =>
        console.log 'received document', data
        @repositoryDelta = data.repositoryDelta
        doc = telepath.Document.deserialize(data.doc, site: telepath.createSite(@getId()))
        atom.windowState = doc.get('windowState')
        @participants = doc.get('collaborationState.participants')
        @participants.on 'changed', =>
          @trigger 'participants-changed', @participants.toObject()
        @repository = doc.get('collaborationState.repositoryState')
        connectDocument(doc, connection)

        @trigger 'started'

        @participants.push
          id: @getId()
          email: git.getConfigValue('user.email')

  getId: -> @peer.id
