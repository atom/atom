fs = require 'fs'
_ = require 'underscore'
async = require 'async'
temp = require 'temp'
telepath = require 'telepath'
{createPeer, connectDocument} = require './session-utils'

module.exports =
class HostSession
  _.extend @prototype, require('event-emitter')

  doc: null
  participants: null
  peer: null
  sharing: false

  bundleUnpushedChanges: (callback) ->
    localBranch = git.getShortHead()
    upstreamBranch = git.getRepo().getUpstreamBranch()

    {exec} = require 'child_process'
    tempFile = temp.path(suffix: '.bundle')
    command = "git bundle create #{tempFile} #{upstreamBranch}..#{localBranch}"
    exec command, {cwd: git.getWorkingDirectory()}, (error, stdout, stderr) ->
      callback(error, tempFile)

  bundleWorkingDirectoryChanges: ->


  bundleRepositoryDelta: (callback) ->
    repositoryDelta = {}

    operations = []
    if git.upstream.ahead > 0
      operations.push (callback) =>
        @bundleUnpushedChanges (error, bundleFile) ->
          unless error?
            repositoryDelta.unpushedChanges = fs.readFileSync(bundleFile, 'base64')
            repositoryDelta.head = git.getRepo().getReferenceTarget(git.getRepo().getHead())
          callback(error)

    async.waterfall operations, (error) ->
      callback(error, repositoryDelta)

    unless _.isEmpty(git.statuses)
      repositoryDelta.workingDirectoryChanges = @bundleWorkingDirectoryChanges()

  start: ->
    return if @peer?

    @peer = createPeer()
    @doc = telepath.Document.create({}, site: telepath.createSite(@getId()))
    @doc.set('windowState', atom.windowState)
    @bundleRepositoryDelta (error, repositoryDelta) =>
      if error?
        console.error(error)
        return

      @doc.set 'collaborationState',
        participants: []
        repositoryState:
          url: git.getConfigValue('remote.origin.url')
          branch: git.getShortHead()

      @participants = @doc.get('collaborationState.participants')
      @participants.push
        id: @getId()
        email: git.getConfigValue('user.email')
      @participants.on 'changed', =>
        @trigger 'participants-changed', @participants.toObject()

      @peer.on 'connection', (connection) =>
        connection.on 'open', =>
          console.log 'sending document'
          connection.send({repositoryDelta, doc: @doc.serialize()})
          connectDocument(@doc, connection)

        connection.on 'close', =>
          console.log 'conection closed'
          @participants.each (participant, index) =>
            if connection.peer is participant.get('id')
              @participants.remove(index)

      @peer.on 'open', =>
        console.log 'sharing session started'
        @sharing = true
        @trigger 'started'

      @peer.on 'close', =>
        console.log 'sharing session stopped'
        @sharing = false
        @trigger 'stopped'

    @getId()

  stop: ->
    return unless @peer?

    @peer.destroy()
    @peer = null

  getId: ->
    @peer.id

  isSharing: ->
    @sharing
