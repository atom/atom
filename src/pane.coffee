{bindKey} = require 'keybinder'

module.exports =
class Pane
  position: null

  html: null

  keymap: ->

  constructor: (options={}) ->
    for option, value of options
      @[option] = value

    for shortcut, method of @keymap()
      bindKey @, shortcut, method

    @initialize options

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

  toggle: ->
    if @showing
      @html.parent().detach()
    else
      # This require should be at the top of the file, BUT it doesn't work.
      # Would like to figure out why.
      {activeWindow} = require 'app'
      activeWindow.addPane this

    @showing = not @showing

  # Override these in your subclass
  initialize: ->

  storageNamespace: -> @.constructor.name