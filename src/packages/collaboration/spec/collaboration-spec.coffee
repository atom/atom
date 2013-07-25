_ = require 'underscore'
keytar = require 'keytar'
{Site} = require 'telepath'

Server = require '../vendor/atom-collaboration-server'
Session = require '../lib/session'

describe "Collaboration", ->
  describe "when a host and a guest join a channel", ->
    [server, hostSession, guestSession, repositoryMirrored, token, userDataByToken] = []

    beforeEach ->
      jasmine.unspy(window, 'setTimeout')
      spyOn(keytar, 'getPassword').andCallFake -> token
      token = 'hubot-token'
      userDataByToken =
        'hubot-token':
          login: 'hubot'
        'octocat-token':
          login: 'octocat'

      server = new Server()
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
        hostSession = new Session(site: new Site(1))
        guestSession = new Session(id: hostSession.getId())

        spyOn(hostSession, 'snapshotRepository').andCallFake (callback) ->
          callback({url: 'git://server/repo.git'})

        spyOn(guestSession, 'mirrorRepository').andCallFake (repoUrl, repoSnapshot, callback) ->
          setTimeout ->
            repositoryMirrored = true
            callback()

    afterEach ->
      waitsFor "server to stop", (stopped) ->
        server.once 'stopped', stopped
        server.stop()

    it "sends the document and file system from the host session to the guest session", ->
      hostSession.start()
      startedHandler = jasmine.createSpy('startedHandler')
      guestSession.on 'started', startedHandler

      waitsFor "host session to start", (started) -> hostSession.one 'started', started

      runs ->
        guestSession.start()

      waitsFor "guest session to receive document", -> guestSession.getDocument()?

      runs ->
        expect(guestSession.mirrorRepository.argsForCall[0][1]).toEqual {url: 'git://server/repo.git'}
        expect(guestSession.getSite().id).toBe 2
        hostSession.getDocument().set('this should', 'replicate')
        guestSession.getDocument().set('this also', 'replicates')

      waitsFor "documents to replicate", ->
        guestSession.getDocument().get('this should') is 'replicate' and
          hostSession.getDocument().get('this also') is 'replicates'

      waitsFor "guest session to start", -> startedHandler.callCount is 1

      runs ->
        expect(repositoryMirrored).toBe true

    it "reports on the participants of the channel", ->
      hostSession.one 'started', hostStartedHandler = jasmine.createSpy("hostStartedHandler")
      guestSession.one 'started', guestStartedHandler = jasmine.createSpy("guestStartedHandler")
      guestSession.one 'stopped', guestStoppedHandler = jasmine.createSpy("guestS")
      hostSession.on 'participant-entered', hostParticipantEnteredHandler = jasmine.createSpy("hostParticipantEnteredHandler")
      hostSession.on 'participant-exited', hostParticipantExitedHandler = jasmine.createSpy("hostParticipantExitedHandler")

      hostSession.start()
      waitsFor "host session to start", -> hostStartedHandler.callCount > 0

      runs ->
        expect(hostStartedHandler).toHaveBeenCalledWith [login: 'hubot', clientId: hostSession.clientId]
        token = 'octocat-token'
        guestSession.start()

      waitsFor "guest session to start", -> guestStartedHandler.callCount > 0

      runs ->
        expect(guestStartedHandler).toHaveBeenCalledWith [
          { login: 'hubot', clientId: hostSession.clientId }
          { login: 'octocat', clientId: guestSession.clientId }
        ]

      waitsFor "host to see guest enter", -> hostParticipantEnteredHandler.callCount > 0

      runs ->
        expect(hostParticipantEnteredHandler).toHaveBeenCalledWith(login: 'octocat', clientId: guestSession.clientId)
        guestSession.stop()

      waitsFor "guest session to stop", -> guestStoppedHandler.callCount > 0
      waitsFor "host to see guest exit", -> hostParticipantExitedHandler.callCount > 0

      runs ->
        expect(hostParticipantExitedHandler).toHaveBeenCalledWith(login: 'octocat', clientId: guestSession.clientId)
