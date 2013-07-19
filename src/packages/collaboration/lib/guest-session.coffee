path = require 'path'
remote = require 'remote'
url = require 'url'

_ = require 'underscore'
patrick = require 'patrick'
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
    connection = @peer.connect(sessionId, reliable: true)

    connection.on 'open', =>
      console.log 'connection opened'
      @trigger 'connection-opened'

    connection.on 'data', (data) =>
      console.log 'received document', data
      @trigger 'connection-document-received'
      @createTelepathDocument(data, connection)

  createTelepathDocument: (data, connection) ->
    doc = telepath.Document.deserialize(data.doc, site: telepath.createSite(@getId()))
    atom.windowState = doc.get('windowState')
    @repository = doc.get('collaborationState.repositoryState')
    @participants = doc.get('collaborationState.participants')
    @participants.on 'changed', =>
      @trigger 'participants-changed', @participants.toObject()
    connectDocument(doc, connection)
    @mirrorRepository(data.repoSnapshot)

  mirrorRepository: (repoSnapshot)->
    repoUrl = @repository.get('url')
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    repoPath = path.join(remote.require('app').getHomeDir(), 'github', repoName)

    progressCallback = (args...) => @trigger 'mirror-progress', args...

    patrick.mirror repoPath, repoSnapshot, {progressCallback}, (error) =>
      if error?
        console.error(error)
      else
        @trigger 'started'

        atom.getLoadSettings().initialPath = repoPath
        window.startEditorWindow()
        @participants.push
          id: @getId()
          email: git.getConfigValue('user.email')

  getId: -> @peer.id
