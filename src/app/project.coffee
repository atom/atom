fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

Buffer = require 'buffer'
EditSession = require 'edit-session'
EventEmitter = require 'event-emitter'
Directory = require 'directory'

module.exports =
class Project
  rootDirectory: null
  editSessions: null
  tabText: null
  autoIndent: null
  softTabs: null
  softWrap: null

  constructor: (path) ->
    @setPath(path)
    @editSessions = []
    @setTabText('  ')
    @setAutoIndent(true)
    @setSoftTabs(true)

  getPath: ->
    @rootDirectory?.path

  setPath: (path) ->
    @rootDirectory?.off()

    if path?
      directory = if fs.isDirectory(path) then path else fs.directory(path)
      @rootDirectory = new Directory(directory)
    else
      @rootDirectory = null

    @trigger "path-change"

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    deferred = $.Deferred()

    filePaths = []
    fs.traverseTree @getPath(), (path, prune) =>
      if @ignorePath(path)
        prune()
      else if fs.isFile(path)
        filePaths.push @relativize(path)

    deferred.resolve filePaths
    deferred

  ignorePath: (path) ->
    fs.base(path).match(/\.DS_Store/) or path.match(/(^|\/)\.git(\/|$)/)

  resolve: (filePath) ->
    filePath = fs.join(@getPath(), filePath) unless filePath[0] == '/'
    fs.absolute filePath

  relativize: (fullPath) ->
    fullPath.replace(@getPath(), "").replace(/^\//, '')

  getTabText: -> @tabText
  setTabText: (@tabText) ->

  getAutoIndent: -> @autoIndent
  setAutoIndent: (@autoIndent) ->

  getSoftTabs: -> @softTabs
  setSoftTabs: (@softTabs) ->

  getSoftWrap: -> @softWrap
  setSoftWrap: (@softWrap) ->

  open: (filePath) ->
    if filePath?
      filePath = @resolve(filePath)
      buffer = @bufferWithPath(filePath) ? @buildBuffer(filePath)
    else
      buffer = @buildBuffer()

    editSession = new EditSession
      buffer: buffer
      tabText: @getTabText()
      autoIndent: @getAutoIndent()
      softTabs: @getSoftTabs()
      softWrap: @getSoftWrap()

    @editSessions.push editSession
    editSession

  buildBuffer: (filePath) ->
    buffer = new Buffer(filePath)
    @trigger 'new-buffer', buffer
    buffer

  getBuffers: ->
    buffers = []
    for editSession in @editSessions when not _.include(buffers, editSession.buffer)
      buffers.push editSession.buffer

    buffers

  bufferWithPath: (path) ->
    return editSession.buffer for editSession in @editSessions when editSession.buffer.getPath() == path

_.extend Project.prototype, EventEmitter
