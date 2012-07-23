EventEmitter = require 'event-emitter'

fs = require 'fs'
_ = require 'underscore'

module.exports =
class File
  path: null
  md5: null

  constructor: (@path) ->
    @updateMd5()

  setPath: (@path) ->

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
    @watchId = $native.watchPath @path, (eventTypes, path) =>
      if eventTypes.removed?
        @trigger 'remove'
      else if eventTypes.moved?
        @setPath(path)
        @trigger 'move'
      else if eventTypes.modified?
        newMd5 = fs.md5ForPath(@getPath())
        return if newMd5 == @md5

        @md5 = newMd5
        @trigger 'contents-change'


  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend File.prototype, EventEmitter
