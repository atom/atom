crypto = require 'crypto'
path = require 'path'
pathWatcher = require 'pathwatcher'
Q = require 'q'
{Emitter} = require 'emissary'
_ = require 'underscore-plus'
fs = require 'fs-plus'

# Public: Represents an individual file.
#
# You should probably create a {Directory} and access the {File} objects that
# it creates, rather than instantiating the {File} class directly.
module.exports =
class File
  Emitter.includeInto(this)

  path: null
  cachedContents: null

  # Public: Creates a new file.
  #
  # * path:
  #   A String containing the absolute path to the file
  # * symlink:
  #   A Boolean indicating if the path is a symlink (default: false)
  constructor: (@path, @symlink=false) ->
    throw new Error("#{@path} is a directory") if fs.isDirectorySync(@path)

    @handleEventSubscriptions()

  # Private: Subscribes to file system notifications when necessary.
  handleEventSubscriptions: ->
    eventNames = ['contents-changed', 'moved', 'removed']

    subscriptionsAdded = eventNames.map (eventName) -> "first-#{eventName}-subscription-will-be-added"
    @on subscriptionsAdded.join(' '), =>
      # Only subscribe when a listener of eventName attaches (triggered by emissary)
      @subscribeToNativeChangeEvents() if @exists()

    subscriptionsRemoved = eventNames.map (eventName) -> "last-#{eventName}-subscription-removed"
    @on subscriptionsRemoved.join(' '), =>
      # Detach when the last listener of eventName detaches (triggered by emissary)
      subscriptionsEmpty = _.every eventNames, (eventName) => @getSubscriptionCount(eventName) is 0
      @unsubscribeFromNativeChangeEvents() if subscriptionsEmpty

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
    fs.writeSync(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  # Private: Deprecated
  readSync: (flushCache) ->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fs.read(@getPath())
    else
      @cachedContents

    @setDigest(@cachedContents)
    @cachedContents

  # Public: Reads the contents of the file.
  #
  # * flushCache:
  #   A Boolean indicating whether to require a direct read or if a cached
  #   copy is acceptable.
  #
  # Returns a promise that resovles to a String.
  read: (flushCache) ->
    if not @exists()
      promise = Q(null)
    else if not @cachedContents? or flushCache
      if fs.getSizeSync(@getPath()) >= 1048576 # 1MB
        throw new Error("Atom can only handle files < 1MB, for now.")

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
        deferred.resolve(content.join(''))

      readStream.on 'error', (error) ->
        deferred.reject(error)
    else
      promise = Q(@cachedContents)

    promise.then (contents) =>
      @setDigest(contents)
      @cachedContents = contents

  # Public: Returns whether the file exists.
  exists: ->
    fsUtils.exists(@getPath())

  setDigest: (contents) ->
    @digest = crypto.createHash('sha1').update(contents ? '').digest('hex')

  getDigest: ->
    @digest ? @setDigest(@readSync())

  # Private:
  handleNativeChangeEvent: (eventType, path) ->
    if eventType is "delete"
      @unsubscribeFromNativeChangeEvents()
      @detectResurrectionAfterDelay()
    else if eventType is "rename"
      @setPath(path)
      @emit "moved"
    else if eventType is "change"
      oldContents = @cachedContents
      @read(true).done (newContents) =>
        @emit 'contents-changed' unless oldContents == newContents

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
      @emit "removed"

  # Private:
  subscribeToNativeChangeEvents: ->
    unless @watchSubscription?
      @watchSubscription = pathWatcher.watch @path, (eventType, path) =>
        @handleNativeChangeEvent(eventType, path)

  # Private:
  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription?
      @watchSubscription.close()
      @watchSubscription = null
