EventEmitter = require 'event-emitter'

fs = require 'fs'
_ = require 'underscore'

module.exports =
class File
  path: null
  md5: null

  constructor: (@path) ->
    throw "Creating file with path that is not a file: #{@path}" unless fs.isFile(@path)
    @updateMd5()

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    fs.base(@path)

  exists: ->
    fs.exists(@getPath())

  updateMd5: ->
    @md5 = fs.md5ForPath(@path)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

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
      @trigger "remove"
      @off()

  subscribeToNativeChangeEvents: ->
    @watchId = $native.watchPath @path, (eventType, path) =>
      @handleNativeChangeEvent(eventType, path)

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
