{Emitter, Disposable} = require 'event-kit'
Notification = require '../src/notification'

# Experimental: Allows messaging the user. This will likely change, dont use
# quite yet!
module.exports =
class NotificationManager
  constructor: ->
    @notifications = []
    @emitter = new Emitter

  ###
  Section: Events
  ###

  onDidAddNotification: (callback) ->
    @emitter.on 'did-add-notification', callback

  ###
  Section: Adding Notifications
  ###

  addSuccess: (message, options) ->
    @addNotification(new Notification('success', message, options))

  addInfo: (message, options) ->
    @addNotification(new Notification('info', message, options))

  addWarning: (message, options) ->
    @addNotification(new Notification('warning', message, options))

  addError: (message, options) ->
    @addNotification(new Notification('error', message, options))

  addFatalError: (message, options) ->
    @addNotification(new Notification('fatal', message, options))

  add: (type, message, options) ->
    @addNotification(new Notification(type, message, options))

  addNotification: (notification) ->
    @notifications.push(notification)
    @emitter.emit('did-add-notification', notification)
    notification

  ###
  Section: Getting Notifications
  ###

  getNotifications: -> @notifications

  ###
  Section: Managing Notifications
  ###

  clear: ->
    @notifications = []
