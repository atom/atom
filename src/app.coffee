Event = require 'event'
Native = require 'native'
KeyBinder = require 'key-binder'
Storage = require 'storage'

module.exports =
class App
  native: new Native
  keybinder: new KeyBinder
  storage: new Storage
  event: new Event

  # atom.on, atom.off, etc.
  @::[name] = @::event[name] for name, method of @::event

  constructor: ->
    @keybinder.register "app", @

  open: (path) ->
    OSX.NSApp.open path

  quit: ->
    OSX.NSApp.terminate null
