_ = require 'underscore'

Event = require 'event'
Extension = require 'extension'
KeyBinder = require 'key-binder'
Storage = require 'storage'
TreePane = require 'tree/tree-pane'
Watcher = require 'watcher'

fs = require 'fs'

module.exports =
class Tree extends Extension
  watcherCallbacks: {}

  constructor: ->
    KeyBinder.register "tree", @
    KeyBinder.load require.resolve "tree/key-bindings.coffee"

    @watchDir atomController.path
    # Remove dirs that no longer exist
    for dir in @shownDirs()
      if not fs.exists dir then @hideDir dir else @watchDir dir

    @pane = new TreePane @

  startup: ->
    @pane.show()

  shutdown: ->
    @unwatchDir dir for dir, callback of @watcherCallbacks

  shownDirStorageKey: ->
    @.constructor.name + ":" + atomController.path + ":shownDirs"

  watchDir: (dir) ->
    @watcherCallbacks[dir] = Watcher.watch dir, =>
      @pane.reload()

  unwatchDir: (dir) ->
    watcher.unwach dir, @watcherCallbacks[dir]

  shownDirs: ->
    Storage.get @shownDirStorageKey(), []

  showDir: (dir) ->
    dirs = @shownDirs().concat dir
    Storage.set @shownDirStorageKey(), dirs
    @watchDir dir

  hideDir: (dir) ->
    dirs = _.without @shownDirs(), dir
    Storage.set @shownDirStorageKey(), dirs
    @unwatchDir dir
    delete @watcherCallbacks[dir]
