_ = require 'underscore'
fs = require 'fs-utils'
File = require 'file'
EventEmitter = require 'event-emitter'

module.exports =
class Directory
  path: null

  constructor: (@path) ->

  getBaseName: ->
    fs.base(@path)

  getPath: -> @path

  getEntries: ->
    directories = []
    files = []
    for path in fs.list(@path)
      if fs.isDirectory(path)
        directories.push(new Directory(path))
      else if fs.isFile(path)
        files.push(new File(path))
      else
        console.error "#{path} is neither a file nor a directory."

    directories.concat(files)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    @watchSubscription = fs.watchPath @path, (eventType) =>
      @trigger "contents-changed" if eventType is "contents-change"

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription?
      @watchSubscription.unwatch()
      @watchSubscription = null

_.extend Directory.prototype, EventEmitter
