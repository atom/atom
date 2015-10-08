{Emitter} = require 'event-kit'
_ = require 'underscore-plus'

# Public: A notification to the user containing a message and type.
module.exports =
class Notification
  constructor: (@type, @message, @options={}) ->
    @emitter = new Emitter
    @timestamp = new Date()
    @dismissed = true
    @dismissed = false if @isDismissable()
    @displayed = false
    @validate()

  validate: ->
    if typeof @message isnt 'string'
      throw new Error("Notification must be created with string message: #{@message}")

    unless _.isObject(@options) and not _.isArray(@options)
      throw new Error("Notification must be created with an options object: #{@options}")

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the notification is dismissed.
  #
  # * `callback` {Function} to be called when the notification is dismissed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDismiss: (callback) ->
    @emitter.on 'did-dismiss', callback

  # Public: Invoke the given callback when the notification is displayed.
  #
  # * `callback` {Function} to be called when the notification is displayed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDisplay: (callback) ->
    @emitter.on 'did-display', callback

  getOptions: -> @options

  ###
  Section: Methods
  ###

  # Public: Returns the {String} type.
  getType: -> @type

  # Public: Returns the {String} message.
  getMessage: -> @message

  getTimestamp: -> @timestamp

  getDetail: -> @options.detail

  isEqual: (other) ->
    @getMessage() is other.getMessage() \
      and @getType() is other.getType() \
      and @getDetail() is other.getDetail()

  # Extended: Dismisses the notification, removing it from the UI. Calling this programmatically
  # will call all callbacks added via `onDidDismiss`.
  dismiss: ->
    return unless @isDismissable() and not @isDismissed()
    @dismissed = true
    @emitter.emit 'did-dismiss', this

  isDismissed: -> @dismissed

  isDismissable: -> !!@options.dismissable

  wasDisplayed: -> @displayed

  setDisplayed: (@displayed) ->
    @emitter.emit 'did-display', this

  getIcon: ->
    return @options.icon if @options.icon?
    switch @type
      when 'fatal' then 'bug'
      when 'error' then 'flame'
      when 'warning' then 'alert'
      when 'info' then 'info'
      when 'success' then 'check'
