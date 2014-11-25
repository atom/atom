
# Experimental: This will likely change, do not use.
module.exports =
class Notification
  constructor: (@type, @message, @options={}) ->
    @timestamp = new Date()

  getOptions: -> @options

  getType: -> @type

  getMessage: -> @message

  getTimestamp: -> @timestamp

  getDetail: -> @options.detail

  isEqual: (other) ->
    @getMessage() == other.getMessage() \
      and @getType() == other.getType() \
      and @getDetail() == other.getDetail()

  isClosable: ->
    !!@options.closable

  getIcon: ->
    return @options.icon if @options.icon?
    switch @type
      when 'fatal' then 'bug'
      when 'error' then 'flame'
      when 'warning' then 'alert'
      when 'info' then 'info'
      when 'success' then 'check'
