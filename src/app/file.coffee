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

  updateMd5: ->
    @md5 = fs.md5ForPath(@path)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    @watchId = $native.watchPath @path, (eventType, path) =>
      if eventType is "remove"
        @trigger "remove"
        @off()
      else if eventType is "move"
        @setPath(path)
        @trigger "move"
      else if eventType is "contents-change"
        newMd5 = fs.md5ForPath(@getPath())
        return if newMd5 == @md5

        @md5 = newMd5
        @trigger 'contents-change'

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
