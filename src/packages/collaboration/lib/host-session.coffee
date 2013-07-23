fs = require 'fs'

_ = require 'underscore'
patrick = require 'patrick'
telepath = require 'telepath'

{createPeer, connectDocument} = require './session-utils'

module.exports =
class HostSession
  _.extend @prototype, require('event-emitter')

  doc: null
  participants: null
  peer: null
  sharing: false
  stream: null

  start: ->
    return if @peer?

    servers = null
    mediaConnection = new webkitRTCPeerConnection(servers)
    mediaConnection.onicecandidate = (event) =>
      return unless event.candidate?
      console.log "Set Host Candidate", event.candidate
      @doc.set 'collaborationState.host.candidate', event.candidate

    mediaConnection.onaddstream = ({@stream}) =>
      @trigger 'stream-ready', @stream
      console.log('Added Stream', @stream)

    constraints = {video: true, audio: true}
    success = (stream) => mediaConnection.addStream(stream)
    navigator.webkitGetUserMedia constraints, success, console.error

    @peer = createPeer()
    @doc = site.createDocument({})
    @doc.set('windowState', atom.windowState)
    patrick.snapshot project.getPath(), (error, repoSnapshot) =>
      if error?
        console.error(error)
        return

      # FIXME: There be dragons here
      @doc.set 'collaborationState',
        guest: {description: '', candidate: '', ready: false}
        host: {description: '', candidate: ''}
        participants: []
        repositoryState:
          url: git.getConfigValue('remote.origin.url')
          branch: git.getShortHead()

      host = @doc.get 'collaborationState.host'
      guest = @doc.get 'collaborationState.guest'
      guest.on 'changed', ({key, newValue}) =>
        switch key
          when 'ready'
            mediaConnection.createOffer (description) =>
              console.log "Create Offer", description
              mediaConnection.setLocalDescription(description)
              host.set 'description', description
          when 'description'
            guestDescription = newValue.toObject()
            console.log "Received Guest description", guestDescription
            sessionDescription = new RTCSessionDescription(guestDescription)
            mediaConnection.setRemoteDescription(sessionDescription)
          when 'candidate'
            guestCandidate = new RTCIceCandidate newValue.toObject()
            console.log('Host received candidate', guestCandidate)
            mediaConnection.addIceCandidate(new RTCIceCandidate(guestCandidate))
          else
            throw new Error("Unknown guest key '#{key}'")

      @participants = @doc.get('collaborationState.participants')
      @participants.push
        id: @getId()
        email: git.getConfigValue('user.email')
      @participants.on 'changed', =>
        @trigger 'participants-changed', @participants.toObject()

      @peer.on 'open', =>
        @sharing = true
        @trigger 'started'

      @peer.on 'close', =>
        @sharing = false
        @trigger 'stopped'

      @peer.on 'connection', (connection) =>
        connection.on 'open', =>
          console.log 'sending document'
          connection.send({repoSnapshot, doc: @doc.serialize()})
          connectDocument(@doc, connection)

        connection.on 'close', =>
          console.log 'sharing session stopped'
          @participants.each (participant, index) =>
            if connection.peer is participant.get('id')
              @participants.remove(index)

    @getId()

  stop: ->
    return unless @peer?

    @peer.destroy()
    @peer = null

  getId: ->
    @peer.id

  isSharing: ->
    @sharing
