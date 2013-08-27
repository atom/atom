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
  _.extend @prototype, EventEmitter

  path: null
  realPath: null

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

  # Retrieves this directory's real path.
  #
  # Returns a {String}.
  getRealPath: ->
    unless @realPath?
      try
        @realPath = fs.realpathSync(@path)
      catch e
        @realPath = @path
    @realPath

  # Is the given path inside this directory?
  #
  # pathToCheck - the {String} path to check.
  #
  # Returns a {Boolean}.
  contains: (pathToCheck) ->
    return false unless pathToCheck

    if pathToCheck.indexOf(path.join(@getPath(), path.sep)) is 0
      true
    else if pathToCheck.indexOf(path.join(@getRealPath(), path.sep)) is 0
      true
    else
      false

  # Make a full path relative to this directory's path.
  #
  # fullPath - The {String} path to convert.
  #
  # Returns a {String}.
  relativize: (fullPath) ->
    return fullPath unless fullPath

    if fullPath is @getPath()
      ''
    else if fullPath.indexOf(path.join(@getPath(), path.sep)) is 0
      fullPath.substring(@getPath().length + 1)
    else if fullPath is @getRealPath()
      ''
    else if fullPath.indexOf(path.join(@getRealPath(), path.sep)) is 0
      fullPath.substring(@getRealPath().length + 1)
    else
      fullPath

  # Retrieves the file entries in the directory.
  #
  # This does follow symlinks.
  #
  # Returns an {Array} of {Files}.
  getEntries: ->
    directories = []
    files = []
    for entryPath in fsUtils.listSync(@path)
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
