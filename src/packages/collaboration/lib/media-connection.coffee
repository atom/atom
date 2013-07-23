_ = require 'underscore'

sessionUtils = require './session-utils'

module.exports =
class MediaConnection
  _.extend @prototype, require('event-emitter')

  guest: null
  host: null
  connection: null
  stream: null

  constructor: (@guest, @host) ->
    constraints = {video: true, audio: true}
    navigator.webkitGetUserMedia constraints, @onUserMediaAvailable, @onUserMediaUnavailable

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
    @host.on 'changed', @onHostSignal

    @connection.onicecandidate = (event) =>
      return unless event.candidate?
      @guest.set 'candidate', event.candidate

    @connection.onaddstream = (event) =>
      @stream = event.stream
      @trigger 'stream-ready', @stream

    @guest.set 'ready', true

  onHostSignal: ({key, newValue}) =>
    switch key
      when 'description'
        hostDescription = newValue.toObject()
        sessionDescription = new RTCSessionDescription(hostDescription)
        @connection.setRemoteDescription(sessionDescription)
        success = (guestDescription) =>
          @connection.setLocalDescription(guestDescription)
          @guest.set('description', guestDescription)

        @connection.createAnswer success, console.error
      when 'candidate'
        hostCandidate = new RTCIceCandidate newValue.toObject()
        @connection.addIceCandidate(hostCandidate)
      else
        throw new Error("Unknown host key '#{key}'")
