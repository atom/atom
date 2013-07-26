$ = require 'jquery'
_ = require 'underscore'

module.exports =
class MediaConnection
  _.extend(@prototype, require 'event-emitter')

  constructor: (@remoteParticipant) ->
    @inboundStreamPromise = $.Deferred()

    @remoteParticipant.on 'add-ice-candidate', (candidate) =>
      @getOutboundStreamPromise().done =>
        @getPeerConnection().addIceCandidate(new RTCIceCandidate(candidate))

    @on 'connected', => @connected = true

  getInboundStreamPromise: -> @inboundStreamPromise

  getOutboundStreamPromise: ->
    @outboundStreamPromise ?= @createOutboundStreamPromise()

  createOutboundStreamPromise: ->
    deferred = $.Deferred()
    video = config.get('collaboration.enableVideo') ? mandatory: { maxWidth: 320, maxHeight: 240 }, optional: []
    audio = config.get('collaboration.enableAudio') ? true
    success = (stream) =>
      @getPeerConnection().addStream(stream)
      deferred.resolve(stream)
    error = (args...) ->
      deferred.reject(args...)
    navigator.webkitGetUserMedia({video, audio}, success, error)
    deferred.promise()

  sendOffer: ->
    @getOutboundStreamPromise().done =>
      @getPeerConnection().createOffer (localDescription) =>
        @getPeerConnection().setLocalDescription(localDescription)
        @remoteParticipant.send('offer-media-connection', localDescription)
        @remoteParticipant.one 'answer-media-connection', (remoteDescription) =>
          @getPeerConnection().setRemoteDescription(new RTCSessionDescription(remoteDescription))
          @trigger 'connected'

  waitForOffer: ->
    @remoteParticipant.one 'offer-media-connection', (remoteDescription) =>
      @getOutboundStreamPromise().done =>
        @getPeerConnection().setRemoteDescription(new RTCSessionDescription(remoteDescription))
        @getPeerConnection().createAnswer (localDescription) =>
          @getPeerConnection().setLocalDescription(localDescription)
          @remoteParticipant.send('answer-media-connection', localDescription)
          @trigger 'connected'

  isConnected: -> @connected

  getPeerConnection: ->
    @peerConnection ?= @createPeerConnection()

  createPeerConnection: ->
    stunServer = {url: "stun:54.218.196.152:3478"}
    turnServer = {url: "turn:ninefingers@54.218.196.152:3478", credential:"youhavetoberealistic"}
    iceServers = [stunServer, turnServer]

    peerConnection = new webkitRTCPeerConnection({iceServers})
    peerConnection.onaddstream = ({stream}) =>
      @inboundStreamPromise.resolve(stream)
    peerConnection.onicecandidate = ({candidate}) =>
      @remoteParticipant.send('add-ice-candidate', candidate) if candidate?
    peerConnection
