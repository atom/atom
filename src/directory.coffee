path = require 'path'
fs = require 'fs-plus'
pathWatcher = require 'pathwatcher'
File = require './file'
{Emitter} = require 'emissary'

# Public: Represents a directory using {File}s
module.exports =
class Directory
  Emitter.includeInto(this)

  path: null
  realPath: null

  # Public: Configures a new Directory instance, no files are accessed.
  #
  # * path:
  #   A String containing the absolute path to the directory.
  # + symlink:
  #   A Boolean indicating if the path is a symlink (defaults to false).
  constructor: (@path, @symlink=false) ->
    @on 'first-contents-changed-subscription-will-be-added', =>
      # Triggered by emissary, when a new contents-changed listener attaches
      @subscribeToNativeChangeEvents()

    @on 'last-contents-changed-subscription-removed', =>
      # Triggered by emissary, when the last contents-changed listener detaches
      @unsubscribeFromNativeChangeEvents()

  # Public: Returns the basename of the directory.
  getBaseName: ->
    path.basename(@path)

  # Public: Returns the directory's symbolic path.
  #
  # This may include unfollowed symlinks or relative directory entries. Or it
  # may be fully resolved, it depends on what you give it.
  getPath: -> @path

  # Public: Returns this directory's completely resolved path.
  #
  # All relative directory entries are removed and symlinks are resolved to
  # their final destination.
  getRealPath: ->
    unless @realPath?
      try
        @realPath = fs.realpathSync(@path)
      catch e
        @realPath = @path
    @realPath

  # Public: Returns whether the given path (real or symbolic) is inside this
  # directory.
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

    # Normalize forward slashes to back slashes on windows
    fullPath = fullPath.replace(/\//g, '\\') if process.platform is 'win32'

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
  # Returns an Array of {Files}.
  getEntries: ->
    directories = []
    files = []
    for entryPath in fs.listSync(@path)
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
