Task = require 'task'

module.exports =
class SpellCheckTask extends Task

  constructor: (@text, @callback) ->
    super('spell-check/lib/spell-check-handler')

  started: ->
    @callWorkerMethod('findMisspellings', @text)

  misspellingsFound: (misspellings) ->
    @done()
    @callback(misspellings)
