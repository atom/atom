_ = require 'underscore'
patrick = require 'patrick'
telepath = require 'telepath'

Project = require 'project'
MediaConnection = require './media-connection'
sessionUtils = require './session-utils'

module.exports =
class GuestSession
  _.extend @prototype, require('event-emitter')

  participants: null
  peer: null
  mediaConnection: null

  constructor: (sessionId) ->
    @peer = sessionUtils.createPeer()
    connection = @peer.connect(sessionId, reliable: true)
    window.site = new telepath.Site(@getId())

    connection.on 'open', =>
      @trigger 'connection-opened'

    connection.once 'data', (data) =>
      @trigger 'connection-document-received'

      doc = @createTelepathDocument(data, connection)
      repoUrl = doc.get('collaborationState.repositoryState.url')

      @mirrorRepository(repoUrl, data.repoSnapshot)

      guest = doc.get('collaborationState.guest')
      host = doc.get('collaborationState.host')
      @mediaConnection = new MediaConnection(guest, host, isHost: false)
      @mediaConnection.start()

  waitForStream: (callback) ->
    @mediaConnection.waitForStream callback

  getId: -> @peer.id

  createTelepathDocument: (data, connection) ->
    doc = window.site.deserializeDocument(data.doc)
    sessionUtils.connectDocument(doc, connection)

    atom.windowState = doc.get('windowState')

    @participants = doc.get('collaborationState.participants')
    @participants.on 'changed', =>
      @trigger 'participants-changed', @participants.toObject()

    doc

  mirrorRepository: (repoUrl, repoSnapshot) ->
    repoPath = Project.pathForRepositoryUrl(repoUrl)

    progressCallback = (args...) => @trigger 'mirror-progress', args...

    patrick.mirror repoPath, repoSnapshot, {progressCallback}, (error) =>
      throw new Error(error) if error

      # 'started' will trigger window.startEditorWindow() which creates the git global
      @trigger 'started'

      id = @getId()
      email = git.getConfigValue('user.email')
      @participants.push {id, email}
