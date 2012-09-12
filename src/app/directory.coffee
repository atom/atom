_ = require 'underscore'
fs = require 'fs'
File = require 'file'
EventEmitter = require 'event-emitter'

module.exports =
class Directory
  path: null

  constructor: (@path) ->

  getBaseName: ->
    fs.base(@path) + '/'

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
    @watchId = $native.watchPath @path, (eventType) =>
      @trigger "contents-change" if eventType is "contents-change"

  unsubscribeFromNativeChangeEvents: ->
    $native.unwatchPath(@path, @watchId)

_.extend Directory.prototype, EventEmitter
