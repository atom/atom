CSON = require 'season'
{CompositeDisposable} = require 'event-kit'

module.exports =
class ScopedProperties
  @load: (scopedPropertiesPath, config, callback) ->
    CSON.readFile scopedPropertiesPath, (error, scopedProperties={}) ->
      if error?
        callback(error)
      else
        callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties, config))

  constructor: (@path, @scopedProperties, @config) ->

  activate: ->
    for selector, properties of @scopedProperties
      @config.set(null, properties, scopeSelector: selector, source: @path)
    return

  deactivate: ->
    for selector of @scopedProperties
      @config.unset(null, scopeSelector: selector, source: @path)
    return
