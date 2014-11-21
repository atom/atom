
# Experimental: This will likely change, do not use.
module.exports =
class Notification
  constructor: (@type, @message, @options={}) ->

  getOptions: -> @options

  getType: -> @type

  getMessage: -> @message

  getDetail: -> @optons.detail

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
