EventEmitter = require 'app/event-emitter'

fs = require 'fs'
_ = require 'underscore'
path = require 'path'

module.exports =
class File
  path: null
  cachedContents: null

  constructor: (@path) ->
    if @exists() and not fs.statSync(@path).isFile()
      throw new Error(@path + " is a directory")

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    path.basename(@path)

  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fs.writeFileSync(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  read: (flushCache)->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fs.readFileSync(@getPath(), 'utf8')
    else
      @cachedContents

  exists: ->
    fs.existsSync(@getPath())

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @exists() and @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  handleNativeChangeEvent: (eventType, path) ->
    if eventType is "remove"
      @detectResurrectionAfterDelay()
    else if eventType is "move"
      @setPath(path)
      @trigger "move"
    else if eventType is "contents-change"
      oldContents = @read()
      newContents = @read(true)
      return if oldContents == newContents
      @trigger 'contents-change'

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("contents-change", @getPath())
    else
      @cachedContents = null
      @unsubscribeFromNativeChangeEvents()
      @trigger "remove"

  subscribeToNativeChangeEvents: ->
#     @watchId = $native.watchPath @path, (eventType, path) =>
#       @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
#     $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
