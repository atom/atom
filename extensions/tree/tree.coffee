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
    @hideDir(dir) for dir in @shownDirs() when not fs.exists dir

    @pane = new TreePane @

  startup: ->
    @pane.show()

  shownDirStorageKey: ->
    @.constructor.name + ":" + atomController.path + ":shownDirs"

  shownDirs: ->
    Storage.get @shownDirStorageKey(), []

  showDir: (dir) ->
    dirs = @shownDirs().concat dir
    Storage.set @shownDirStorageKey(), dirs

  hideDir: (dir) ->
    dirs = _.without @shownDirs(), dir
    Storage.set @shownDirStorageKey(), dirs
