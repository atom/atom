EventEmitter = require 'event-emitter'

fs = require 'fs'
_ = require 'underscore'

module.exports =
class File
  path: null
  md5: null

  constructor: (@path) ->
    if @exists() and not fs.isFile(@path)
      throw new Error(@path + " is a directory")

    @updateMd5() if @exists()

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    fs.base(@path)

  write: (text) ->
    previouslyExisted = @exists()
    fs.write(@getPath(), text)
    @updateMd5()
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  exists: ->
    fs.exists(@getPath())

  updateMd5: ->
    @md5 = fs.md5ForPath(@path)

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
      newMd5 = fs.md5ForPath(@getPath())
      return if newMd5 == @md5

      @md5 = newMd5
      @trigger 'contents-change'

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("contents-change", @getPath())
    else
      @unsubscribeFromNativeChangeEvents()
      @trigger "remove"

  subscribeToNativeChangeEvents: ->
    @watchId = $native.watchPath @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
