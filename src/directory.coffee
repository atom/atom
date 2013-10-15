fs = require 'fs'
path = require 'path'
fsUtils = require './fs-utils'
pathWatcher = require 'pathwatcher'
File = require './file'
{Emitter} = require 'emissary'

# Public: Represents a directory using {File}s
module.exports =
class Directory
  Emitter.includeInto(this)

  path: null
  realPath: null

  # Public: Configures an new Directory instance, no files are accessed.
  #
  # * path:
  #   A {String} representing the file directory
  # + symlink:
  #   A {Boolean} indicating if the path is a symlink
  constructor: (@path, @symlink=false) ->
    @on 'first-contents-changed-subscription-will-be-added', =>
      @subscribeToNativeChangeEvents()

    @on 'last-contents-changed-subscription-removed', =>
      @unsubscribeFromNativeChangeEvents()

  # Public: Returns the basename of the directory.
  getBaseName: ->
    path.basename(@path)

  # Public: Returns the directory's path.
  #
  # FIXME what is the difference between real path and path?
  getPath: -> @path

  # Public: Returns this directory's real path.
  #
  # FIXME what is the difference between real path and path?
  getRealPath: ->
    unless @realPath?
      try
        @realPath = fs.realpathSync(@path)
      catch e
        @realPath = @path
    @realPath

  # Public: Returns whether the given path is inside this directory.
  contains: (pathToCheck) ->
    return false unless pathToCheck

    if pathToCheck.indexOf(path.join(@getPath(), path.sep)) is 0
      true
    else if pathToCheck.indexOf(path.join(@getRealPath(), path.sep)) is 0
      true
    else
      false

  # Public: Returns the relative path to the given path from this directory.
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

  # Public: Reads file entries in this directory from disk.
  #
  # Note: It follows symlinks.
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

  # Private:
  subscribeToNativeChangeEvents: ->
    unless @watchSubscription?
      @watchSubscription = pathWatcher.watch @path, (eventType) =>
        @emit "contents-changed" if eventType is "change"

  # Private:
  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription?
      @watchSubscription.close()
      @watchSubscription = null
