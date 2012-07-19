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

  getPath: ->
    @path

  getName: ->
    fs.base(@path)

  updateMd5: ->
    @md5 = fs.md5ForPath(@path)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    @watchId = $native.watchPath @path, (eventTypes) =>
      newMd5 = fs.md5ForPath(@getPath())
      if eventTypes.modified? and newMd5 != @md5
        @md5 = newMd5
        @trigger 'contents-change'

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
