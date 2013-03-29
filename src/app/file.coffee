EventEmitter = require 'event-emitter'

fs = require 'fs'
fsUtils = require 'fs-utils'
path = require 'path'
_ = require 'underscore'

module.exports =
class File
  path: null
  cachedContents: null

  constructor: (@path, @symlink=false) ->
    try
      if fs.statSync(@path).isDirectory()
        throw new Error("#{@path} is a directory")

  setPath: (@path) ->

  getPath: -> @path

  getBaseName: ->
    fsUtils.base(@path)

  write: (text) ->
    previouslyExisted = @exists()
    @cachedContents = text
    fsUtils.write(@getPath(), text)
    @subscribeToNativeChangeEvents() if not previouslyExisted and @subscriptionCount() > 0

  read: (flushCache)->
    if not @exists()
      @cachedContents = null
    else if not @cachedContents? or flushCache
      @cachedContents = fsUtils.read(@getPath())
    else
      @cachedContents

  exists: ->
    fsUtils.exists(@getPath())

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @exists() and @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  handleNativeChangeEvent: (event, path) ->
    if event is "change"
      oldContents = @read()
      newContents = @read(true)
      return if oldContents == newContents
      @trigger "contents-changed"
    else if event is "rename"
      if not path? # file deleted
        @unsubscribeFromNativeChangeEvents()
        @detectResurrectionAfterDelay()
      else
        # This is how Vim did an atomic file save:
        # 1. rename /path/file to /path/file~
        # 2. write content to /path/file
        # 3. remove /path/file~
        #
        # So after receiving a rename event, we should first unsubscribe the
        # fs.watch, otherwise it's possible that we will then receive a delete
        # event before we find out whether it's an atomic write.
        @unsubscribeFromNativeChangeEvents()

        # Then we should wait a while to give external editor a chance to write
        # content back, and then check whether it's an atomic write or a real
        # file renaming.
        setTimeout =>
          # Is the original file still there?
          fs.stat @getPath(), (err, stats) =>
            if not err? # atomic write
              @subscribeToNativeChangeEvents()
              @handleNativeChangeEvent("change", null)
            else
              # Is the path passed by rename event real?
              fs.stat path, (err) =>
                if err? # file is deleted after rename
                  @handleNativeChangeEvent("rename", null)
                else # file is renamed
                  @setPath(path)
                  @subscribeToNativeChangeEvents()
                  @trigger "moved"
          , 100

  detectResurrectionAfterDelay: ->
    _.delay (=> @detectResurrection()), 50

  detectResurrection: ->
    if @exists()
      @subscribeToNativeChangeEvents()
      @handleNativeChangeEvent("change", null)
    else
      @cachedContents = null
      @unsubscribeFromNativeChangeEvents()
      @trigger "removed"

  subscribeToNativeChangeEvents: ->
    @watchSubscription = fs.watch @getPath(), (event, path) =>
      @handleNativeChangeEvent(event, path)

  unsubscribeFromNativeChangeEvents: ->
    if @watchSubscription
      @watchSubscription.close()
      @watchSubscription = null

_.extend File.prototype, EventEmitter
