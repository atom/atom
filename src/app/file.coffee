EventEmitter = require 'event-emitter'

fs = require 'fs'
fsUtils = require 'fs-utils'
path = require 'path'
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

  handleNativeChangeEvent: (event, filename) ->
    console.log event, filename
    if event is "change"
      console.log "change", filename
      oldContents = @read()
      newContents = @read(true)
      return if oldContents == newContents
      @trigger 'contents-changed'
    else if event is "rename"
      if not filename? # file deleted
        @detectResurrectionAfterDelay()
      else # file moved
        @setPath(path.join(@getPath(), filename))
        @trigger "moved"

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("change")
    else
      @cachedContents = null
      @unsubscribeFromNativeChangeEvents()
      @trigger "removed"

  subscribeToNativeChangeEvents: ->
    @watchSubscription = fs.watch @path, (event, path) =>
      @handleNativeChangeEvent(event, path)

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription
      @watchSubscription.close()
      @watchSubscription = null

_.extend File.prototype, EventEmitter
