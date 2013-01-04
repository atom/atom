EventEmitter = require 'event-emitter'

fs = require 'fs'
_ = require 'underscore'

module.exports =
class File
  path: null
  cachedContents: null

  constructor: (@path) ->
    if @exists() and not fs.isFile(@path)
      throw new Error(@path + " is a directory")

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    fs.base(@path)

  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fs.write(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  read: (flushCache)->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fs.read(@getPath())
    else
      @cachedContents

  exists: ->
    fs.exists(@getPath())

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @exists() and @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  handleNativeChangeEvent: (eventType, path) ->
    if eventType is "remove"
      @detectResurrectionAfterDelay()
    else if eventType is "move"
      @setPath(path)
      @trigger "moved"
    else if eventType is "contents-change"
      oldContents = @read()
      newContents = @read(true)
      return if oldContents == newContents
      @trigger 'contents-changed'

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("contents-change", @getPath())
    else
      @cachedContents = null
      @unsubscribeFromNativeChangeEvents()
      @trigger "removed"

  subscribeToNativeChangeEvents: ->
    @watchId = $native.watchPath @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
