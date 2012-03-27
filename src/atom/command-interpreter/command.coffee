_ = require 'underscore'

module.exports =
class Command
  isAddress: -> false

  regexForPattern: (pattern) ->
    new RegExp(pattern, 'm')
