{bindKey} = require 'keybinder'

module.exports =
class Plugin
  constructor: (@window) ->
    console.log "Loaded Plugin: " + @.constructor.name

    for shortcut, method of @keymap()
      bindKey @, shortcut, method

  # Called after all plugins are loaded
  load: ->

  pane: ->

  keymap: ->

  storageNamespace: -> @.constructor.name

  get: (key, defaultValue) ->
    try
      object = JSON.parse(localStorage[@storageNamespace()] ? "{}")
    catch error
      error.message += "\nGetting #{key}"
      console.log(error)

    object[key] ? defaultValue

  set: (key, value) ->
    try
      object = JSON.parse(localStorage[@storageNamespace()] ? "{}")
    catch error
      error.message += "\nSetting #{key}: #{value}"
      console.log(error)

    # Putting data in
    if value == undefined
      delete object[key]
    else
      object[key] = value
    localStorage[@storageNamespace()] = JSON.stringify(object)


