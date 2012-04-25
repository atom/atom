_ = require 'underscore'
fs = require 'fs'
File = require 'file'
EventEmitter = require 'event-emitter'

module.exports =
class Directory
  constructor: (@path) ->

  getName: ->
    fs.base(@path) + '/'

  getEntries: ->
    directories = []
    files = []
    for path in fs.list(@path)
      if fs.isDirectory(path)
        directories.push(new Directory(path))
      else
        files.push(new File(path))
    directories.concat(files)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    $native.watchPath @path, (eventTypes) =>
      @trigger 'contents-change' if eventTypes.modified?

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path)

_.extend Directory.prototype, EventEmitter

