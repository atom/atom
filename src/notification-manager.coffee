{Emitter, Disposable} = require 'event-kit'
Notification = require '../src/notification'

# Public: A notification manager used to create {Notification}s to be shown
# to the user.
module.exports =
class NotificationManager
  constructor: ->
    @notifications = []
    @emitter = new Emitter

  ###
  Section: Events
  ###

  # Public: Invoke the given callback after a notification has been added.
  #
  # * `callback` {Function} to be called after the notification is added.
  #   * `notification` The {Notification} that was added.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddNotification: (callback) ->
    @emitter.on 'did-add-notification', callback

  ###
  Section: Adding Notifications
  ###

  # Public: Add a success notification.
  #
  # * `message` A {String} message
  # * `options` An options {Object} with optional keys such as:
  #    * `detail` A {String} with additional details about the notification
  addSuccess: (message, options) ->
    @addNotification(new Notification('success', message, options))

  # Public: Add an informational notification.
  #
  # * `message` A {String} message
  # * `options` An options {Object} with optional keys such as:
  #    * `detail` A {String} with additional details about the notification
  addInfo: (message, options) ->
    @addNotification(new Notification('info', message, options))

  # Public: Add a warning notification.
  #
  # * `message` A {String} message
  # * `options` An options {Object} with optional keys such as:
  #    * `detail` A {String} with additional details about the notification
  addWarning: (message, options) ->
    @addNotification(new Notification('warning', message, options))

  # Public: Add an error notification.
  #
  # * `message` A {String} message
  # * `options` An options {Object} with optional keys such as:
  #    * `detail` A {String} with additional details about the notification
  addError: (message, options) ->
    @addNotification(new Notification('error', message, options))

  # Public: Add a fatal error notification.
  #
  # * `message` A {String} message
  # * `options` An options {Object} with optional keys such as:
  #    * `detail` A {String} with additional details about the notification
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

  # Public: Get all the notifications.
  #
  # Returns an {Array} of {Notifications}s.
  getNotifications: -> @notifications.slice()

  ###
  Section: Managing Notifications
  ###

  clear: ->
    @notifications = []
