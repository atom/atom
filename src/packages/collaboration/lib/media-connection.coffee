_ = require 'underscore'

sessionUtils = require './session-utils'

module.exports =
class MediaConnection
  _.extend @prototype, require('event-emitter')

  local: null
  remote: null
  connection: null
  stream: null
  isLeader: null

  constructor: (@local, @remote, {@isLeader}={}) ->

  start: ->
    video = config.get('collaboration.enableVideo') ? true
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
    @remote.on 'changed', @onRemoteSignal

    @connection.onicecandidate = (event) =>
      return unless event.candidate?
      @local.set 'candidate', event.candidate

    @connection.onaddstream = (event) =>
      @stream = event.stream
      @trigger 'stream-ready', @stream

    @local.set 'ready', true unless @isLeader

  onRemoteSignal: ({key, newValue}) =>
    switch key
      when 'ready'
        success = (description) =>
          @connection.setLocalDescription(description)
          @local.set 'description', description
        @connection.createOffer success, console.error

      when 'description'
        remoteDescription = newValue.toObject()
        sessionDescription = new RTCSessionDescription(remoteDescription)
        @connection.setRemoteDescription(sessionDescription)

        if not @isLeader
          success = (localDescription) =>
            @connection.setLocalDescription(localDescription)
            @local.set('description', localDescription)
          @connection.createAnswer success, console.error

      when 'candidate'
        remoteCandidate = new RTCIceCandidate newValue.toObject()
        @connection.addIceCandidate(remoteCandidate)

      else
        throw new Error("Unknown remote key '#{key}'")
