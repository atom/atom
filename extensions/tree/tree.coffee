_ = require 'underscore'

Event = require 'event'
Extension = require 'extension'
KeyBinder = require 'key-binder'
Storage = require 'storage'
TreePane = require 'tree/tree-pane'

fs = require 'fs'

module.exports =
class Tree extends Extension
  constructor: ->
    KeyBinder.register "tree", @
    KeyBinder.load require.resolve "tree/key-bindings.coffee"

    # Remove dirs that no longer exist
    openedPaths = @getOpenedDirs()
    for dir in openedPaths when not fs.exists dir
      openedDirs = _.without openedDirs, path
      @setOpenedDirs openedDirs

    @pane = new TreePane @

  storageNamespace: ->
    @.constructor.name + ":" + atomController.path

  getOpenedDirs: ->
    Storage.get @storageNamespace() + ':openedDirs', []

  setOpenedDirs: (value) ->
    Storage.set @storageNamespace() + ':openedDirs', value

  startup: ->
    @pane.show()
