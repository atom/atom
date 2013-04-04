EventEmitter = require 'event-emitter'

fs = require 'fs'
fsUtils = require 'fs-utils'
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

  write: (text, callback) ->
    previouslyExisted = @exists()
    @cachedContents = text
    done = (err) =>
      if err?
        callback(err)
      else
        @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0
        callback(null)
    fsUtils.writeAsync @getPath(), text, (err) =>
      if err?.code is "EACCES"
        fsUtils.writeWithPrivileges @getPath(), text, done
      else
        done(err)

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
    @watchSubscription = fsUtils.watchPath @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription
      @watchSubscription.unwatch()
      @watchSubscription = null

_.extend File.prototype, EventEmitter
