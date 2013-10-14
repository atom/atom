Q = require 'q'
{EventEmitter} = require 'emissary'
path = require 'path'
fsUtils = require './fs-utils'
pathWatcher = require 'pathwatcher'
_ = require './underscore-extensions'

# Public: Represents an individual file in the editor.
#
# This class shouldn't be created directly, instead you should create a
# {Directory} and access the {File} objects that it creates.
module.exports =
class File
  _.extend @prototype, EventEmitter

  path: null
  cachedContents: null

  # Private: Creates a new file.
  #
  # * path:
  #   A String representing the file path
  # * symlink:
  #   A Boolean indicating if the path is a symlink (default: false)
  constructor: (@path, @symlink=false) ->
    throw new Error("#{@path} is a directory") if fsUtils.isDirectorySync(@path)

  # Private: Sets the path for the file.
  setPath: (@path) ->

  # Public: Returns the path for the file.
  getPath: -> @path

  # Public: Return the filename without any directory information.
  getBaseName: ->
    path.basename(@path)

  # Public: Overwrites the file with the given String.
  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fsUtils.writeSync(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  # Private: Deprecated
  read: (flushCache) ->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fsUtils.read(@getPath())
    else
      @cachedContents

  # Public: Reads the contents of the file.
  #
  # * flushCache:
  #   A Boolean indicating whether to require a direct read or if a cached
  #   copy is acceptable.
  #
  # Returns a promise that resovles to a String.
  readAsync: (flushCache) ->
    if not @exists()
      promise = Q(null)
    else if not @cachedContents? or flushCache
      deferred = Q.defer()
      promise = deferred.promise

      content = []
      bytesRead = 0
      readStream = fsUtils.createReadStream @getPath(), encoding: 'utf8'
      readStream.on 'data', (chunk) ->
        content.push(chunk)
        bytesRead += chunk.length
        deferred.notify(bytesRead)

      readStream.on 'end', ->
        deferred.resolve(content.join())

      readStream.on 'error', (error) ->
        deferred.reject(error)
    else
      promise = Q(@cachedContents)

    promise.then (contents) ->
      @cachedContents = contents

  # Public: Returns whether a file exists.
  exists: ->
    fsUtils.exists(@getPath())

  # Private:
  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @exists() and @subscriptionCount() == 1

  # Private:
  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  # Private:
  handleNativeChangeEvent: (eventType, path) ->
    if eventType is "delete"
      @unsubscribeFromNativeChangeEvents()
      @detectResurrectionAfterDelay()
    else if eventType is "rename"
      @setPath(path)
      @trigger "moved"
    else if eventType is "change"
      oldContents = @cachedContents
      newContents = @read(true)
      return if oldContents == newContents
      @trigger 'contents-changed'

  # Private:
  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  # Private:
  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("change", @getPath())
    else
      @cachedContents = null
      @trigger "removed"

  # Private:
  subscribeToNativeChangeEvents: ->
    @watchSubscription = pathWatcher.watch @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  # Private:
  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription
      @watchSubscription.close()
      @watchSubscription = null
