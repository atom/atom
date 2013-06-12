_ = require 'underscore'
fsUtils = require 'fs-utils'
Subscriber = require 'subscriber'
EventEmitter = require 'event-emitter'
RepositoryStatusTask = require 'repository-status-task'
GitUtils = require 'git-utils'

# Public: Represents the underlying git operations performed by Atom.
#
# Ultimately, this is an overlay to the native [git-utils](https://github.com/atom/node-git) module.
module.exports =
class Git
  path: null
  statuses: null
  upstream: null
  statusTask: null

  ### Internal ###

  # Creates a new `Git` object.
  #
  # path - The {String} representing the path to your git working directory
  # options - A hash with the following keys:
  #           refreshOnWindowFocus: If `true`, {#refreshIndex} and {#refreshStatus} are called on focus
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

  destroy: ->
    if @statusTask?
      @statusTask.abort()
      @statusTask.off()
      @statusTask = null

    if @repo?
      @repo.release()
      @repo = null

    @unsubscribe()

  ### Public ###

  # Creates a new `Git` instance.
  #
  # path - The git repository to open
  # options - A hash with one key:
  #           refreshOnWindowFocus: A {Boolean} that identifies if the windows should refresh
  #
  # Returns a new {Git} object.
  @open: (path, options) ->
    return null unless path
    try
      new Git(path, options)
    catch e
      null

  # Retrieves the git repository.
  #
  # Returns a new `Repository`.
  getRepo: ->
    unless @repo?
      throw new Error("Repository has been destroyed")
    @repo

  # Reread the index to update any values that have changed since the last time the index was read.
  refreshIndex: -> @getRepo().refreshIndex()

  # Retrieves the path of the repository.
  #
  # Returns a {String}.
  getPath: ->
    @path ?= fsUtils.absolute(@getRepo().getPath())

  # Retrieves the working directory of the repository.
  #
  # Returns a {String}.
  getWorkingDirectory: -> @getRepo().getWorkingDirectory()

  # Retrieves the status of a single path in the repository.
  #
  # path - An {String} defining a relative path
  #
  # Returns a {Number}.
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

  # Identifies if a path is ignored.
  #
  # path - The {String} path to check
  #
  # Returns a {Boolean}.
  isPathIgnored: (path) -> @getRepo().isIgnored(@relativize(path))

  # Identifies if a value represents a status code.
  #
  # status - The code {Number} to check
  #
  # Returns a {Boolean}.
  isStatusModified: (status) -> @getRepo().isStatusModified(status)

  # Identifies if a path was modified.
  #
  # path - The {String} path to check
  #
  # Returns a {Boolean}.
  isPathModified: (path) -> @isStatusModified(@getPathStatus(path))

  # Identifies if a status code represents a new path.
  #
  # status - The code {Number} to check
  #
  # Returns a {Boolean}.
  isStatusNew: (status) -> @getRepo().isStatusNew(status)

  # Identifies if a path is new.
  #
  # path - The {String} path to check
  #
  # Returns a {Boolean}.
  isPathNew: (path) -> @isStatusNew(@getPathStatus(path))

  # Makes a path relative to the repository's working directory.
  #
  # path - The {String} path to convert
  #
  # Returns a {String}.
  relativize: (path) -> @getRepo().relativize(path)

  # Retrieves a shortened version of the HEAD reference value.
  #
  # This removes the leading segments of `refs/heads`, `refs/tags`, or `refs/remotes`.
  # It also shortens the SHA-1 of a detached `HEAD` to 7 characters.
  #
  # Returns a {String}.
  getShortHead: -> @getRepo().getShortHead()

  # Restore the contents of a path in the working directory and index to the version at `HEAD`.
  #
  # This is essentially the same as running:
  # ```
  # git reset HEAD -- <path>
  # git checkout HEAD -- <path>
  # ```
  #
  # path - The {String} path to checkout
  #
  # Returns a {Boolean} that's `true` if the method was successful.
  checkoutHead: (path) ->
    headCheckedOut = @getRepo().checkoutHead(@relativize(path))
    @getPathStatus(path) if headCheckedOut
    headCheckedOut

  # Retrieves the number of lines added and removed to a path.
  #
  # This compares the working directory contents of the path to the `HEAD` version.
  #
  # path - The {String} path to check
  #
  # Returns an object with two keys, `added` and `deleted`. These will always be greater than 0.
  getDiffStats: (path) -> @getRepo().getDiffStats(@relativize(path))

  # Identifies if a path is a submodule.
  #
  # path - The {String} path to check
  #
  # Returns a {Boolean}.
  isSubmodule: (path) -> @getRepo().isSubmodule(@relativize(path))

  # Retrieves the status of a directory.
  #
  # path - The {String} path to check
  #
  # Returns a {Number} representing the status.
  getDirectoryStatus: (directoryPath)  ->
    directoryPath = "#{directoryPath}/"
    directoryStatus = 0
    for path, status of @statuses
      directoryStatus |= status if path.indexOf(directoryPath) is 0
    directoryStatus

  # Retrieves the line diffs comparing the `HEAD` version of the given path and the given text.
  #
  # This is similar to the commit numbers reported by `git status` when a remote tracking branch exists.
  #
  # path - The {String} path (relative to the repository)
  # text - The {String} to compare against the `HEAD` contents
  #
  # Returns an object with two keys, `ahead` and `behind`. These will always be greater than zero.
  getLineDiffs: (path, text) -> @getRepo().getLineDiffs(@relativize(path), text)

  ### Internal ###

  refreshStatus: ->
    if @statusTask?
      @statusTask.off()
      @statusTask.one 'task:completed', =>
        @statusTask = null
        @refreshStatus()
    else
      @statusTask = new RepositoryStatusTask(this)
      @statusTask.one 'task:completed', =>
        @statusTask = null
      @statusTask.start()

_.extend Git.prototype, Subscriber
_.extend Git.prototype, EventEmitter
