EventEmitter = require 'event-emitter'

fs = require 'fs'
fsUtils = require 'fs-utils'
pathWatcher = require 'pathwatcher'
_ = require 'underscore'

module.exports =
class File
  path: null
  cachedContents: null

  constructor: (@path, @symlink=false) ->
    try
      if fs.statSync(@path).isDirectory()
        throw new Error("#{@path} is a directory")

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    fsUtils.base(@path)

  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fsUtils.write(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  read: (flushCache)->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fsUtils.read(@getPath())
    else
      @cachedContents

  exists: ->
    fsUtils.exists(@getPath())

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
