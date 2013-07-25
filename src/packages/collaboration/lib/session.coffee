_ = require 'underscore'
keytar = require 'keytar'

WsChannel = require './ws-channel'

module.exports =
class Session
  _.extend @prototype, require('event-emitter')

  subscribe: (channelName) ->
    channel = new WsChannel(channelName)
    {@clientId} = channel
    channel

  connectDocument: (doc, channel) ->
    doc.on 'replicate-change', (event) ->
      channel.send('document-changed', event)

    channel.on 'document-changed', (event) ->
      doc.applyRemoteChange(event)
