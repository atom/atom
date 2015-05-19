{Emitter} = require 'event-kit'

# Public: A notification to the user containing a message and type.
module.exports =
class Notification
  constructor: (@type, @message, @options={}) ->
    @emitter = new Emitter
    @timestamp = new Date()
    @dismissed = true
    @dismissed = false if @isDismissable()
    @displayed = false

  onDidDismiss: (callback) ->
    @emitter.on 'did-dismiss', callback

  onDidDisplay: (callback) ->
    @emitter.on 'did-display', callback

  getOptions: -> @options

  # Public: Retrieves the {String} type.
  getType: -> @type

  # Public: Retrieves the {String} message.
  getMessage: -> @message

  getTimestamp: -> @timestamp

  getDetail: -> @options.detail

  isEqual: (other) ->
    @getMessage() is other.getMessage() \
      and @getType() is other.getType() \
      and @getDetail() is other.getDetail()

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
