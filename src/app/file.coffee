EventEmitter = require 'event-emitter'
fs = require 'fs'
path = require 'path'
fsUtils = require 'fs-utils'
pathWatcher = require 'pathwatcher'
_ = require 'underscore'

# Public: Represents an individual file in the editor.
#
# The entry point for this class is in two locations:
# * {Buffer}, which associates text contents with a file
# * {Directory}, which associcates the children of a directory as files
module.exports =
class File
  path: null
  cachedContents: null

  # Creates a new file.
  #
  # path - A {String} representing the file path
  # symlink - A {Boolean} indicating if the path is a symlink (default: false)
  constructor: (@path, @symlink=false) ->
    try
      if fs.statSync(@path).isDirectorySync()
        throw new Error("#{@path} is a directory")

  # Sets the path for the file.
  #
  # path - A {String} representing the new file path
  setPath: (@path) ->

  # Retrieves the path for the file.
  #
  # Returns a {String}.
  getPath: -> @path

  # Gets the file's basename--that is, the file without any directory information.
  #
  # Returns a {String}.
  getBaseName: ->
    path.basename(@path)

  # Writes (and saves) new contents to the file.
  #
  # text - A {String} representing the new contents.
  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fsUtils.writeSync(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  # Reads the file.
  #
  # flushCache - A {Boolean} indicating if the cache should be erased--_i.e._, a force read is performed
  #
  # Returns a {String}.
  read: (flushCache)->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fsUtils.read(@getPath())
    else
      @cachedContents

  # Checks to see if a file exists.
  #
  # Returns a {Boolean}.
  exists: ->
    fsUtils.exists(@getPath())

  ### Internal ###

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @exists() and @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  handleNativeChangeEvent: (eventType, path) ->
    if eventType is "delete"
      @unsubscribeFromNativeChangeEvents()
      @detectResurrectionAfterDelay()
    else if eventType is "rename"
      @setPath(path)
      @trigger "moved"
    else if eventType is "change"
      oldContents = @read()
      newContents = @read(true)
      return if oldContents == newContents
      @trigger 'contents-changed'

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("change", @getPath())
    else
      @cachedContents = null
      @trigger "removed"

  subscribeToNativeChangeEvents: ->
    @watchSubscription = pathWatcher.watch @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription
      @watchSubscription.close()
      @watchSubscription = null

_.extend File.prototype, EventEmitter
