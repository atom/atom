_ = require 'underscore'
fs = require 'fs'
fsUtils = require 'fs-utils'
pathWatcher = require 'pathwatcher'
File = require 'file'
EventEmitter = require 'event-emitter'

module.exports =
class Directory
  path: null

  constructor: (@path, @symlink=false) ->

  getBaseName: ->
    fsUtils.base(@path)

  getPath: -> @path

  getEntries: ->
    directories = []
    files = []
    for path in fsUtils.list(@path)
      try
        stat = fs.lstatSync(path)
        symlink = stat.isSymbolicLink()
        stat = fs.statSync(path) if symlink
      catch e
        continue
      if stat.isDirectory()
        directories.push(new Directory(path, symlink))
      else if stat.isFile()
        files.push(new File(path, symlink))

    directories.concat(files)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
    @watchSubscription = pathWatcher.watch @path, (eventType) =>
      @trigger "contents-changed" if eventType is "change"

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription?
      @watchSubscription.close()
      @watchSubscription = null

_.extend Directory.prototype, EventEmitter
