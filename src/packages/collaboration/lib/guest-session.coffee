path = require 'path'
remote = require 'remote'
url = require 'url'

_ = require 'underscore'
patrick = require 'patrick'
telepath = require 'telepath'

Project = require 'project'
{connectDocument, createPeer} = require './session-utils'

module.exports =
class GuestSession
  _.extend @prototype, require('event-emitter')

  participants: null
  repository: null
  peer: null
  stream: null

  constructor: (sessionId) ->
    @peer = createPeer()
    connection = @peer.connect(sessionId, reliable: true)

    connection.on 'open', =>
      console.log 'connection opened'
      @trigger 'connection-opened'

    connection.once 'data', (data) =>
      console.log 'received document', data
      @trigger 'connection-document-received'
      @createTelepathDocument(data, connection)

  createTelepathDocument: (data, connection) ->
    window.site = new telepath.Site(@getId())
    doc = window.site.deserializeDocument(data.doc)

    servers = {iceServers: [{url: "stun:54.218.196.152:3478"}, {url: "turn:ninefingers@54.218.196.152:3478", credential:"youhavetoberealistic"}]}
    mediaConnection = null

    constraints = {video: true, audio: true}
    success = (stream) =>
      mediaConnection = new webkitRTCPeerConnection(servers)
      mediaConnection.onicecandidate = (event) =>
        return unless event.candidate?
        console.log "Set Guest Candidate", event.candidate
        doc.set 'collaborationState.guest.candidate', event.candidate

      mediaConnection.onaddstream = ({@stream}) =>
        @trigger 'stream-ready', @stream
        console.log('Added Host\'s Stream', @stream)

      mediaConnection.addStream(stream)
      guest = doc.get 'collaborationState.guest'
      guest.set 'ready', true

    navigator.webkitGetUserMedia constraints, success, console.error

    atom.windowState = doc.get('windowState')
    @repository = doc.get('collaborationState.repositoryState')

    @participants = doc.get('collaborationState.participants')
    @participants.on 'changed', =>
      @trigger 'participants-changed', @participants.toObject()

    guest = doc.get 'collaborationState.guest'
    host = doc.get('collaborationState.host')
    host.on 'changed', ({key, newValue}) =>
      switch key
        when 'description'
          hostDescription = newValue.toObject()
          console.log "Received host description", hostDescription
          sessionDescription = new RTCSessionDescription(hostDescription)
          mediaConnection.setRemoteDescription(sessionDescription)
          success = (guestDescription) =>
            console.log "Set guest description", guestDescription
            mediaConnection.setLocalDescription(guestDescription)
            guest.set('description', guestDescription)

          console.log "COOL?", mediaConnection?
          mediaConnection.createAnswer success, console.error
        when 'candidate'
          hostCandidate = new RTCIceCandidate newValue.toObject()
          console.log('Guest received candidate', hostCandidate)
          mediaConnection.addIceCandidate(hostCandidate)
        else
          throw new Error("Unknown host key '#{key}'")

    connectDocument(doc, connection)
    @mirrorRepository(data.repoSnapshot)

  mirrorRepository: (repoSnapshot) ->
    repoPath = Project.pathForRepositoryUrl(@repository.get('url'))

    progressCallback = (args...) => @trigger 'mirror-progress', args...

    patrick.mirror repoPath, repoSnapshot, {progressCallback}, (error) =>
      if error?
        console.error(error)
      else
        @trigger 'started'

        window.startEditorWindow()
        @participants.push
          id: @getId()
          email: git.getConfigValue('user.email')

  getId: -> @peer.id
