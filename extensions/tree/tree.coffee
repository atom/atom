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
  constructor: ->
    KeyBinder.register "tree", @
    KeyBinder.load require.resolve "tree/key-bindings.coffee"

    # watch the root dir
    Watcher.watch window.path, @watchDir

    # Hide dirs that no longer exist, watch dirs that do.
    for dir in @shownDirs()
      if not fs.exists dir
        @hideDir dir
      else
        Watcher.watch dir, @watchDir

    @pane = new TreePane @

  startup: ->
    @pane.show()

  shutdown: ->
    @unwatchDir dir for dir in @shownDirs()

  shownDirStorageKey: ->
    @.constructor.name + ":" + window.path + ":shownDirs"

  watchDir: (dir) =>
    @pane.reload()

  unwatchDir: (dir) ->
    Watcher.unwatch dir, @watchDir

  shownDirs: ->
    Storage.get @shownDirStorageKey(), []

  showDir: (dir) ->
    dirs = @shownDirs().concat dir
    Storage.set @shownDirStorageKey(), dirs
    Watcher.watch dir, @watchDir


  hideDir: (dir) ->
    dirs = _.without @shownDirs(), dir
    Storage.set @shownDirStorageKey(), dirs
    @unwatchDir dir, @watchDir
