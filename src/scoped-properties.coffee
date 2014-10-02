CSON = require 'season'

module.exports =
class ScopedProperties
  @load: (scopedPropertiesPath, callback) ->
    CSON.readFile scopedPropertiesPath, (error, scopedProperties={}) ->
      if error?
        callback(error)
      else
        callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties))

  constructor: (@path, @scopedProperties) ->

  activate: ->
    for selector, properties of @scopedProperties
      atom.config.addScopedDefaults(@path, selector, properties)

  deactivate: ->
    atom.config.removeScopedSettingsForName(@path)
