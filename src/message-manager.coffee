{Emitter, Disposable} = require 'event-kit'
Message = require '../src/message'

# Experimental: Allows messaging the user. This will likely change, dont use
# quite yet!
module.exports =
class MessageManager
  constructor: ->
    @messages = []
    @emitter = new Emitter

  ###
  Section: Events
  ###

  onDidAddMessage: (callback) ->
    @emitter.on 'did-add-message', callback

  ###
  Section: Adding Messages
  ###

  addSuccess: (messageString, options) ->
    @addMessage(new Message('success', messageString, options))

  addInfo: (messageString, options) ->
    @addMessage(new Message('info', messageString, options))

  addWarning: (messageString, options) ->
    @addMessage(new Message('warning', messageString, options))

  addError: (messageString, options) ->
    @addMessage(new Message('error', messageString, options))

  addFatalError: (messageString, options) ->
    @addMessage(new Message('fatal', messageString, options))

  add: (type, messageString, options) ->
    @addMessage(new Message(type, messageString, options))

  addMessage: (message) ->
    @messages.push(message)
    @emitter.emit('did-add-message', message)
    message
