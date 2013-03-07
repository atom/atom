_ = require 'underscore'
fs = require 'fs'
Subscriber = require 'subscriber'
EventEmitter = require 'event-emitter'
GitRepository = require 'git-repository'
RepositoryStatusTask = require 'repository-status-task'

module.exports =
class Git
  @open: (path, options) ->
    return null unless path
    try
      new Git(path, options)
    catch e
      null

  statusFlags:
    index_new: 1 << 0
    index_modified: 1 << 1
    index_deleted: 1 << 2
    index_renamed: 1 << 3
    index_typechange: 1 << 4
    working_dir_new: 1 << 7
    working_dir_modified: 1 << 8
    working_dir_delete: 1 << 9
    working_dir_typechange: 1 << 10
    ignore: 1 << 14

  statuses: null
  upstream: null
  statusTask: null

  constructor: (path, options={}) ->
    @statuses = {}
    @upstream = {ahead: 0, behind: 0}
    @repo = GitRepository.open(path)
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
    @path ?= fs.absolute(@getRepo().getPath())

  destroy: ->
    if @statusTask?
      @statusTask.abort()
      @statusTask.off()
      @statusTask = null

    @getRepo().destroy()
    @repo = null
    @unsubscribe()

  getWorkingDirectory: ->
    @getPath()?.replace(/\/\.git\/?$/, '')

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

  isStatusModified: (status=0) ->
    modifiedFlags = @statusFlags.working_dir_modified |
                    @statusFlags.working_dir_delete |
                    @statusFlags.working_dir_typechange |
                    @statusFlags.index_modified |
                    @statusFlags.index_deleted |
                    @statusFlags.index_typechange
    (status & modifiedFlags) > 0

  isPathModified: (path) ->
    @isStatusModified(@getPathStatus(path))

  isStatusNew: (status=0) ->
    newFlags = @statusFlags.working_dir_new |
               @statusFlags.index_new
    (status & newFlags) > 0

  isPathNew: (path) ->
    @isStatusNew(@getPathStatus(path))

  relativize: (path) ->
    workingDirectory = @getWorkingDirectory()
    if workingDirectory and path.indexOf("#{workingDirectory}/") is 0
      path.substring(workingDirectory.length + 1)
    else
      path

  getShortHead: ->
    head = @getHead()
    return head.substring(11) if head.indexOf('refs/heads/') is 0
    return head.substring(10) if head.indexOf('refs/tags/') is 0
    return head.substring(13) if head.indexOf('refs/remotes/') is 0
    return head.substring(0, 7) if head.match(/[a-fA-F0-9]{40}/)
    return head

  checkoutHead: (path) ->
    headCheckedOut = @getRepo().checkoutHead(@relativize(path))
    @getPathStatus(path) if headCheckedOut
    headCheckedOut

  getDiffStats: (path) ->
    @getRepo().getDiffStats(@relativize(path)) ? added: 0, deleted: 0

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
    @getRepo().getAheadBehindCounts() ? ahead: 0, behind: 0

  getLineDiffs: (path, text) ->
    @getRepo().getLineDiffs(@relativize(path), text) ? []

_.extend Git.prototype, Subscriber
_.extend Git.prototype, EventEmitter
