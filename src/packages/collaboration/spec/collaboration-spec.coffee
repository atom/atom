_ = require 'underscore'
keytar = require 'keytar'
{Site} = require 'telepath'

GuestSession = require '../lib/guest-session'
HostSession = require '../lib/host-session'

class PusherServer
  constructor: ->
    @channels = {}

  getChannel: (channelName) ->
    @channels[channelName] ?= new ChannelServer(channelName)

  createClient: -> new PusherClient(this)

class ChannelServer
  constructor: (@name) ->
    @channelClients = {}

  subscribe: (subscribingClient) ->
    channelClient = new ChannelClient(subscribingClient, this)
    @channelClients[subscribingClient.id] = channelClient
    setTimeout =>
      for client in @getChannelClients()
        if client is channelClient
          client.trigger 'channel:opened'
        else
          client.trigger 'channel:participant-joined'
    channelClient

  getChannelClients: -> _.values(@channelClients)

  send: (sendingClient, eventName, eventData) ->
    setTimeout =>
      for client in @getChannelClients() when client isnt sendingClient
        client.trigger(eventName, eventData)

class PusherClient
  @nextId: 1

  constructor: (@server) ->
    @id = @constructor.nextId++

  subscribe: (channelName) ->
    @server.getChannel(channelName).subscribe(this)

class ChannelClient
  _.extend @prototype, require('event-emitter')

  constructor: (@pusherClient, @channelServer) ->

  send: (eventName, eventData) ->
    @channelServer.send(this, eventName, eventData)

describe "Collaboration", ->
  describe "joining a host session", ->
    [hostSession, guestSession, pusher, repositoryMirrored] = []

    beforeEach ->
      spyOn(keytar, 'getPassword')
      jasmine.unspy(window, 'setTimeout')
      pusherServer = new PusherServer()
      hostSession = new HostSession(new Site(1))
      spyOn(hostSession, 'snapshotRepository').andCallFake (callback) ->
        callback({url: 'git://server/repo.git'})
      spyOn(hostSession, 'subscribe').andCallFake (channelName) ->
        pusherServer.createClient().subscribe(channelName)
      guestSession = new GuestSession(hostSession.getId())
      spyOn(guestSession, 'subscribe').andCallFake (channelName) ->
        pusherServer.createClient().subscribe(channelName)
      spyOn(guestSession, 'mirrorRepository').andCallFake (repoUrl, repoSnapshot, callback) ->
        setTimeout ->
          repositoryMirrored = true
          callback()

    it "sends the document from the host session to the guest session", ->
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
