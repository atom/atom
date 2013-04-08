_ = require 'underscore'
fsUtils = require 'fs-utils'
Subscriber = require 'subscriber'
EventEmitter = require 'event-emitter'
RepositoryStatusTask = require 'repository-status-task'
GitUtils = require 'git-utils'

module.exports =
class Git
  @open: (path, options) ->
    return null unless path
    try
      new Git(path, options)
    catch e
      null

  statuses: null
  upstream: null
  statusTask: null

  constructor: (path, options={}) ->
    @repo = GitUtils.open(path)
    unless @repo?
      throw new Error("No Git repository found searching path: #{path}")

    @statuses = {}
    @upstream = {ahead: 0, behind: 0}

    refreshOnWindowFocus = options.refreshOnWindowFocus ? true
    if refreshOnWindowFocus
      $ = require 'jquery'
      @subscribe $(window), 'focus', =>
        @refreshIndex()
        @refreshStatus()

    project?.eachBuffer this, (buffer) =>
      bufferStatusHandler = =>
        path = buffer.getPath()
        @getPathStatus(path) if path
      @subscribe buffer, 'saved', bufferStatusHandler
      @subscribe buffer, 'reloaded', bufferStatusHandler

  getRepo: ->
    unless @repo?
      throw new Error("Repository has been destroyed")
    @repo

  refreshIndex: -> @getRepo().refreshIndex()

  getPath: ->
    @path ?= fsUtils.absolute(@getRepo().getPath())

  destroy: ->
    if @statusTask?
      @statusTask.abort()
      @statusTask.off()
      @statusTask = null

    if @repo?
      @repo.release()
      @repo = null

    @unsubscribe()

  getWorkingDirectory: ->
    @getRepo().getWorkingDirectory()

  getHead: ->
    @getRepo().getHead() ? ''

  getPathStatus: (path) ->
    currentPathStatus = @statuses[path] ? 0
    pathStatus = @getRepo().getStatus(@relativize(path)) ? 0
    if pathStatus > 0
      @statuses[path] = pathStatus
    else
      delete @statuses[path]
    if currentPathStatus isnt pathStatus
      @trigger 'status-changed', path, pathStatus
    pathStatus

  isPathIgnored: (path) ->
    @getRepo().isIgnored(@relativize(path))

  isStatusModified: (status) ->
    @getRepo().isStatusModified(status)

  isPathModified: (path) ->
    @isStatusModified(@getPathStatus(path))

  isStatusNew: (status) ->
    @getRepo().isStatusNew(status)

  isPathNew: (path) ->
    @isStatusNew(@getPathStatus(path))

  relativize: (path) ->
    workingDirectory = @getWorkingDirectory()
    if workingDirectory and path.indexOf("#{workingDirectory}/") is 0
      path.substring(workingDirectory.length + 1)
    else
      path

  getShortHead: ->
    @getRepo().getShortHead()

  checkoutHead: (path) ->
    headCheckedOut = @getRepo().checkoutHead(@relativize(path))
    @getPathStatus(path) if headCheckedOut
    headCheckedOut

  getDiffStats: (path) ->
    @getRepo().getDiffStats(@relativize(path))

  isSubmodule: (path) ->
    @getRepo().isSubmodule(@relativize(path))

  refreshStatus: ->
    if @statusTask?
      @statusTask.off()
      @statusTask.one 'task-completed', =>
        @statusTask = null
        @refreshStatus()
    else
      @statusTask = new RepositoryStatusTask(this)
      @statusTask.one 'task-completed', =>
        @statusTask = null
      @statusTask.start()

  getDirectoryStatus: (directoryPath) ->
    directoryPath = "#{directoryPath}/"
    directoryStatus = 0
    for path, status of @statuses
      directoryStatus |= status if path.indexOf(directoryPath) is 0
    directoryStatus

  getAheadBehindCounts: ->
    @getRepo().getAheadBehindCount()

_.extend Git.prototype, Subscriber
_.extend Git.prototype, EventEmitter
