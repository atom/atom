_ = require 'underscore'
fs = require 'fs'
path = require 'path'
File = require 'app/file'
EventEmitter = require 'app/event-emitter'

module.exports =
class Directory
  path: null

  constructor: (@path) ->

  getBaseName: ->
    path.basename(@path) + '/'

  getPath: -> @path

  getEntries: ->
    directories = []
    files = []
    for fileName in fs.readdirSync(@path)
      pathName = path.join(@path, fileName)
      if fs.statSync(pathName).isDirectory()
        directories.push(new Directory(pathName))
      else if fs.statSync(pathName).isFile()
        files.push(new File(pathName))
      else
        console.error "#{pathName} is neither a file nor a directory."

    directories.concat(files)

  afterSubscribe: ->
    @subscribeToNativeChangeEvents() if @subscriptionCount() == 1

  afterUnsubscribe: ->
    @unsubscribeFromNativeChangeEvents() if @subscriptionCount() == 0

  subscribeToNativeChangeEvents: ->
#     @watchId = $native.watchPath @path, (eventType) =>
#       @trigger "contents-change" if eventType is "contents-change"

  unsubscribeFromNativeChangeEvents: ->
#     $native.unwatchPath(@path, @watchId)

_.extend Directory.prototype, EventEmitter
