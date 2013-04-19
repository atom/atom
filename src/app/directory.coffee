_ = require 'underscore'
fs = require 'fs'
fsUtils = require 'fs-utils'
pathWatcher = require 'pathwatcher'
File = require 'file'
EventEmitter = require 'event-emitter'

# Public: Represents a directory in the project.
#
# Directories contain an array of {File}s.
module.exports =
class Directory
  path: null

  # Public: Creates a new directory.
  #
  # path - A {String} representing the file directory
  # symlink - A {Boolean} indicating if the path is a symlink (default: false)
  constructor: (@path, @symlink=false) ->

  # Public: Retrieves the basename of the directory.
  #
  # Returns a {String}.
  getBaseName: ->
    fsUtils.base(@path)

  # Public: Retrieves the directory's path.
  #
  # Returns a {String}.
  getPath: -> @path

  # Public: Retrieves the file entries in the directory.
  #
  # This does follow symlinks.
  #
  # Returns an {Array} of {Files}.
  getEntries: ->
    directories = []
    files = []
    for path in fsUtils.list(@path)
      try
        stat = fs.lstatSync(path)
        symlink = stat.isSymbolicLink()
        stat = fs.statSync(path) if symlink
      catch e
        continue
      if stat.isDirectory()
        directories.push(new Directory(path, symlink))
      else if stat.isFile()
        files.push(new File(path, symlink))

    directories.concat(files)

  ###
  # Internal #
  ###

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    @watchSubscription = pathWatcher.watch @path, (eventType) =>
      @trigger "contents-changed" if eventType is "change"

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription?
      @watchSubscription.close()
      @watchSubscription = null

_.extend Directory.prototype, EventEmitter
