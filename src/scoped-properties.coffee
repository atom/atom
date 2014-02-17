fs = require 'fs-plus'

module.exports =
class ScopedProperties
  @load: (scopedPropertiesPath, callback) ->
    fs.readObject scopedPropertiesPath, (error, scopedProperties={}) ->
      if error?
        callback(error)
      else
        callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties))

  constructor: (@path, @scopedProperties) ->

  activate: ->
    for selector, properties of @scopedProperties
      atom.syntax.addProperties(@path, selector, properties)

  deactivate: ->
    atom.syntax.removeProperties(@path)
