_ = require 'underscore'
keytar = require 'keytar'
{Site} = require 'telepath'

Server = require '../vendor/atom-collaboration-server'
Session = require '../lib/session'

ServerHost = 'localhost'
ServerPort = 8081

describe "Collaboration", ->
  describe "when a host and a guest join a channel", ->
    [server, token, userDataByToken] = []
    [leaderSession, leaderStartedHandler, leaderParticipantEnteredHandler, leaderParticipantExitedHandler] = []
    [guestSession, guestStartedHandler, guestStoppedHandler] = []

    beforeEach ->
      jasmine.unspy(window, 'setTimeout')
      spyOn(keytar, 'getPassword').andCallFake -> token
      token = 'hubot-token'
      userDataByToken =
        'hubot-token':
          login: 'hubot'
        'octocat-token':
          login: 'octocat'

      server = new Server(port: ServerPort, secure: false)
      spyOn(server, 'log')
      spyOn(server, 'error')
      spyOn(server, 'authenticate').andCallFake (token, callback) ->
        if userData = userDataByToken[token]
          callback(null, userData)
        else
          callback("Invalid token")

      waitsFor "server to start", (started) ->
        server.once 'started', started
        server.start()

      runs ->
        leaderSession = new Session(site: new Site(1), host: ServerHost, port: ServerPort, secure: false)
        leaderSession.one 'started', leaderStartedHandler = jasmine.createSpy("leaderStartedHandler")
        leaderSession.on 'participant-entered', leaderParticipantEnteredHandler = jasmine.createSpy("leaderParticipantEnteredHandler")
        leaderSession.on 'participant-exited', leaderParticipantExitedHandler = jasmine.createSpy("leaderParticipantExitedHandler")

        guestSession = new Session(id: leaderSession.getId(), host: ServerHost, port: ServerPort, secure: false)
        guestSession.one 'started', guestStartedHandler = jasmine.createSpy("guestStartedHandler")
        guestSession.one 'stopped', guestStoppedHandler = jasmine.createSpy("guestStoppedHandler")

        spyOn(leaderSession, 'snapshotRepository').andCallFake (callback) -> callback({url: 'git://server/repo.git'})

        spyOn(Session.prototype, 'mirrorRepository').andCallFake (repoUrl, repoSnapshot, callback) ->
          setTimeout =>
            @repositoryMirrored = true
            callback()

    afterEach ->
      waitsFor "server to stop", (stopped) ->
        server.once 'stopped', stopped
        server.stop()

    it "sends the document and file system from the host session to the guest session", ->
      leaderSession.start()

      waitsFor "leader session to start", -> leaderStartedHandler.callCount > 0

      runs -> guestSession.start()

      waitsFor "guest session to receive document", -> guestSession.getDocument()?

      runs ->
        expect(guestSession.mirrorRepository.argsForCall[0][1]).toEqual {url: 'git://server/repo.git'}
        expect(guestSession.getSite().id).toBe 2
        leaderSession.getDocument().set('this should', 'replicate')
        guestSession.getDocument().set('this also', 'replicates')

      waitsFor "documents to replicate", ->
        guestSession.getDocument().get('this should') is 'replicate' and
          leaderSession.getDocument().get('this also') is 'replicates'

      waitsFor "guest session to start", -> guestStartedHandler.callCount is 1

      runs -> expect(guestSession.repositoryMirrored).toBe true

    it "reports on the participants of the channel", ->
      leaderSession.start()
      waitsFor "leader session to start", -> leaderStartedHandler.callCount > 0

      runs ->
        expect(leaderStartedHandler).toHaveBeenCalledWith [login: 'hubot', clientId: leaderSession.clientId]
        expect(leaderSession.getParticipants()).toEqual [login: 'hubot', clientId: leaderSession.clientId]
        expect(leaderSession.getOtherParticipants()).toEqual []
        token = 'octocat-token'
        guestSession.start()

      waitsFor "guest session to start", -> guestStartedHandler.callCount > 0

      runs ->
        expect(guestStartedHandler).toHaveBeenCalledWith [
          { login: 'hubot', clientId: leaderSession.clientId }
          { login: 'octocat', clientId: guestSession.clientId }
        ]
        expect(guestSession.getParticipants()).toEqual [
          { login: 'hubot', clientId: leaderSession.clientId }
          { login: 'octocat', clientId: guestSession.clientId }
        ]
        expect(guestSession.getOtherParticipants()).toEqual [
          { login: 'hubot', clientId: leaderSession.clientId }
        ]

      waitsFor "leader to see guest enter", -> leaderParticipantEnteredHandler.callCount > 0

      runs ->
        expect(leaderParticipantEnteredHandler).toHaveBeenCalledWith(login: 'octocat', clientId: guestSession.clientId)
        expect(leaderSession.getParticipants()).toEqual [
          { login: 'hubot', clientId: leaderSession.clientId }
          { login: 'octocat', clientId: guestSession.clientId }
        ]
        expect(leaderSession.getOtherParticipants()).toEqual [
          { login: 'octocat', clientId: guestSession.clientId }
        ]
        guestSession.stop()

      waitsFor "guest session to stop", -> guestStoppedHandler.callCount > 0
      waitsFor "host to see guest exit", -> leaderParticipantExitedHandler.callCount > 0

      runs ->
        expect(leaderParticipantExitedHandler).toHaveBeenCalledWith(login: 'octocat', clientId: guestSession.clientId)
        expect(leaderSession.getParticipants()).toEqual [login: 'hubot', clientId: leaderSession.clientId]
        expect(leaderSession.getOtherParticipants()).toEqual []

        siteIdMap = leaderSession.getClientIdToSiteIdMap()
        expect(siteIdMap.get(leaderSession.clientId)).toEqual 1
        expect(siteIdMap.get(guestSession.clientId)).toEqual 2

    it "performs a webrtc handshake between all participants", ->
      leaderSession.start()
      waitsFor "leader session to start", -> leaderStartedHandler.callCount > 0

      runs ->
        token = 'octocat-token'
        guestSession.start()

      waitsFor "leader to see guest enter", -> leaderParticipantEnteredHandler.callCount > 0

      [leaderGuestMediaConnection, guestLeaderMediaConnection] = []
      runs ->
        leaderGuestMediaConnection = leaderSession.getOtherParticipants()[0].mediaConnection
        guestLeaderMediaConnection = guestSession.getOtherParticipants()[0].mediaConnection

      waitsFor "media connection to be established between leader and guest", ->
        leaderGuestMediaConnection.isConnected() and guestLeaderMediaConnection.isConnected()

      # This will fail when there is no internet connection
      waitsFor "media stream to be established on leader and guest", (stream1Established, stream2Established) ->
        leaderGuestMediaConnection.getInboundStreamPromise().done(stream1Established)
        guestLeaderMediaConnection.getInboundStreamPromise().done(stream2Established)
