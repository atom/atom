CSON = require 'season'
{CompositeDisposable} = require 'event-kit'

module.exports =
class ScopedProperties
  @load: (scopedPropertiesPath, callback) ->
    CSON.readFile scopedPropertiesPath, (error, scopedProperties={}) ->
      if error?
        callback(error)
      else
        callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties))

  constructor: (@path, @scopedProperties) ->
    @propertyDisposable = new CompositeDisposable

  activate: ->
    for selector, properties of @scopedProperties
      @propertyDisposable.add atom.config.addScopedSettings(@path, selector, properties)
    return

  deactivate: ->
    @propertyDisposable.dispose()
