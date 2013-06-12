_ = require 'underscore'
fs = require 'fs'
path = require 'path'
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

  ### Public ###

  # Creates a new directory.
  #
  # path - A {String} representing the file directory
  # symlink - A {Boolean} indicating if the path is a symlink (default: false)
  constructor: (@path, @symlink=false) ->

  # Retrieves the basename of the directory.
  #
  # Returns a {String}.
  getBaseName: ->
    path.basename(@path)

  # Retrieves the directory's path.
  #
  # Returns a {String}.
  getPath: -> @path

  # Retrieves the file entries in the directory.
  #
  # This does follow symlinks.
  #
  # Returns an {Array} of {Files}.
  getEntries: ->
    directories = []
    files = []
    for entryPath in fsUtils.list(@path)
      try
        stat = fs.lstatSync(entryPath)
        symlink = stat.isSymbolicLink()
        stat = fs.statSync(entryPath) if symlink
      catch e
        continue
      if stat.isDirectory()
        directories.push(new Directory(entryPath, symlink))
      else if stat.isFile()
        files.push(new File(entryPath, symlink))

    directories.concat(files)

  ### Internal ###

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
