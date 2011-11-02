KeyBinder = require 'key-binder'
fs = require 'fs'

module.exports =
class Extension
  constructor: ->
    console.log "#{@constructor.name}: Loaded"

  storageNamespace: -> @constructor.name

  startup: ->

  shutdown: ->

  pane: ->

  # This should be stored keyed on the window path I think? But what if the path
  # changes?
  get: (key, defaultValue) ->
    try
      object = JSON.parse(localStorage[@storageNamespace()] ? "{}")
    catch error
      error.message += "\nGetting #{key}"
      console.error(error)

    object[key] ? defaultValue

  set: (key, value) ->
    try
      object = JSON.parse(localStorage[@storageNamespace()] ? "{}")
    catch error
      error.message += "\nSetting #{key}: #{value}"
      console.error(error)

    if value == undefined
      delete object[key]
    else
      object[key] = value

    localStorage[@storageNamespace()] = JSON.stringify(object)



