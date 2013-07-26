_ = require 'underscore'

sessionUtils = require './session-utils'

module.exports =
class MediaConnection
  _.extend @prototype, require('event-emitter')

  channel: null
  connection: null
  stream: null
  isLeader: null

  constructor: (@channel, {@isLeader}={}) ->

  start: ->
    video = config.get('collaboration.enableVideo') ? mandatory: { maxWidth: 320, maxHeight: 240 }, optional: []
    audio = config.get('collaboration.enableAudio') ? true
    navigator.webkitGetUserMedia({video, audio}, @onUserMediaAvailable, @onUserMediaUnavailable)

  waitForStream: (callback) ->
    if @stream
      callback(@stream)
    else
      @on 'stream-ready', callback

  onUserMediaUnavailable: (args...) =>
    console.error "User's webcam is unavailable.", args...

  onUserMediaAvailable: (stream) =>
    @connection = new webkitRTCPeerConnection(sessionUtils.getIceServers())
    @connection.addStream(stream)
    @channel.on 'media-handshake', (event) =>
      try
        @onSignal(event)
      catch e
        console.error event
        throw e

    @connection.onicecandidate = (event) =>
      return unless event.candidate?
      @channel.send 'media-handshake', {candidate: event.candidate}

    @connection.onaddstream = (event) =>
      @stream = event.stream
      @trigger 'stream-ready', @stream

    unless @isLeader
      @channel.send 'media-handshake', {ready: true}

  onSignal: (event) =>
    if value = event.ready
      success = (description) =>
        @connection.setLocalDescription(description)
        @channel.send 'media-handshake', {description}
      @connection.createOffer success, console.error

    else if value = event.description
      remoteDescription = value
      sessionDescription = new RTCSessionDescription(remoteDescription)
      @connection.setRemoteDescription(sessionDescription)

      if not @isLeader
        success = (localDescription) =>
          @connection.setLocalDescription(localDescription)
          @channel.send 'media-handshake', {description: localDescription}
        @connection.createAnswer success, console.error

    else if value = event.candidate
      remoteCandidate = new RTCIceCandidate value
      @connection.addIceCandidate(remoteCandidate)
    else
      throw new Error("Unknown remote key '#{event}'")
