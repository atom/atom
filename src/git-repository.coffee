{join} = require 'path'

_ = require 'underscore-plus'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
fs = require 'fs-plus'
path = require 'path'
GitUtils = require 'git-utils'

StatusHandlerHelper = require './repository-status-handler-helper'

# Extended: Represents the underlying git operations performed by Atom.
#
# This class shouldn't be instantiated directly but instead by accessing the
# `atom.project` global and calling `getRepositories()`. Note that this will
# only be available when the project is backed by a Git repository.
#
# This class handles submodules automatically by taking a `path` argument to many
# of the methods.  This `path` argument will determine which underlying
# repository is used.
#
# For a repository with submodules this would have the following outcome:
#
# ```coffee
# repo = atom.project.getRepositories()[0]
# repo.getShortHead() # 'master'
# repo.getShortHead('vendor/path/to/a/submodule') # 'dead1234'
# ```
#
# ## Examples
#
# ### Logging the URL of the origin remote
#
# ```coffee
# git = atom.project.getRepositories()[0]
# console.log git.getOriginURL()
# ```
#
# ### Requiring in packages
#
# ```coffee
# {GitRepository} = require 'atom'
# ```
module.exports =
class GitRepository
  @exists: (path) ->
    if git = @open(path)
      git.destroy()
      true
    else
      false

  ###
  Section: Construction and Destruction
  ###

  # Public: Creates a new GitRepository instance.
  #
  # * `path` The {String} path to the Git repository to open.
  # * `options` An optional {Object} with the following keys:
  #   * `refreshOnWindowFocus` A {Boolean}, `true` to refresh the index and
  #     statuses when the window is focused.
  #
  # Returns a {GitRepository} instance or `null` if the repository could not be opened.
  @open: (path, options) ->
    return null unless path
    try
      new GitRepository(path, options)
    catch
      null

  constructor: (path, options={}) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable

    @repo = GitUtils.open(path)
    unless @repo?
      throw new Error("No Git repository found searching path: #{path}")

    @statuses = {}
    @upstream = {ahead: 0, behind: 0}
    for submodulePath, submoduleRepo of @repo.submodules
      submoduleRepo.upstream = {ahead: 0, behind: 0}

    {@project, @config, refreshOnWindowFocus} = options

    refreshOnWindowFocus ?= true
    if refreshOnWindowFocus
      onWindowFocus = =>
        @refreshIndex()
        @refreshStatus()

      window.addEventListener 'focus', onWindowFocus
      @subscriptions.add new Disposable(-> window.removeEventListener 'focus', onWindowFocus)

    if @project?
      @project.getBuffers().forEach (buffer) => @subscribeToBuffer(buffer)
      @subscriptions.add @project.onDidAddBuffer (buffer) => @subscribeToBuffer(buffer)

  # Public: Destroy this {GitRepository} object.
  #
  # This destroys any tasks and subscriptions and releases the underlying
  # libgit2 repository handle. This method is idempotent.
  destroy: ->
    if @emitter?
      @emitter.emit 'did-destroy'
      @emitter.dispose()
      @emitter = null

    if @repo?
      @repo.release()
      @repo = null

    if @subscriptions?
      @subscriptions.dispose()
      @subscriptions = null

  # Public: Returns a {Boolean} indicating if this repository has been destroyed.
  isDestroyed: ->
    not @repo?

  # Public: Invoke the given callback when this GitRepository's destroy() method
  # is invoked.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when a specific file's status has
  # changed. When a file is updated, reloaded, etc, and the status changes, this
  # will be fired.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `path` {String} the old parameters the decoration used to have
  #     * `pathStatus` {Number} representing the status. This value can be passed to
  #       {::isStatusModified} or {::isStatusNew} to get more information.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatus: (callback) ->
    @emitter.on 'did-change-status', callback

  # Public: Invoke the given callback when a multiple files' statuses have
  # changed. For example, on window focus, the status of all the paths in the
  # repo is checked. If any of them have changed, this will be fired. Call
  # {::getPathStatus(path)} to get the status for your path of choice.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatuses: (callback) ->
    @emitter.on 'did-change-statuses', callback

  ###
  Section: Repository Details
  ###

  # Public: A {String} indicating the type of version control system used by
  # this repository.
  #
  # Returns `"git"`.
  getType: -> 'git'

  # Public: Returns the {String} path of the repository.
  getPath: ->
    @path ?= fs.absolute(@getRepo().getPath())

  # Public: Returns the {String} working directory path of the repository.
  getWorkingDirectory: -> @getRepo().getWorkingDirectory()

  # Public: Returns true if at the root, false if in a subfolder of the
  # repository.
  isProjectAtRoot: ->
    @projectAtRoot ?= @project?.relativize(@getWorkingDirectory()) is ''

  # Public: Makes a path relative to the repository's working directory.
  relativize: (path) -> @getRepo().relativize(path)

  # Public: Returns true if the given branch exists.
  hasBranch: (branch) -> @getReferenceTarget("refs/heads/#{branch}")?

  # Public: Retrieves a shortened version of the HEAD reference value.
  #
  # This removes the leading segments of `refs/heads`, `refs/tags`, or
  # `refs/remotes`.  It also shortens the SHA-1 of a detached `HEAD` to 7
  # characters.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository contains submodules.
  #
  # Returns a {String}.
  getShortHead: (path) -> @getRepo(path).getShortHead()

  # Public: Is the given path a submodule in the repository?
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Boolean}.
  isSubmodule: (path) ->
    return false unless path

    repo = @getRepo(path)
    if repo.isSubmodule(repo.relativize(path))
      true
    else
      # Check if the path is a working directory in a repo that isn't the root.
      repo isnt @getRepo() and repo.relativize(join(path, 'dir')) is 'dir'

  # Public: Returns the number of commits behind the current branch is from the
  # its upstream remote branch.
  #
  # * `reference` The {String} branch reference name.
  # * `path`      The {String} path in the repository to get this information for,
  #   only needed if the repository contains submodules.
  getAheadBehindCount: (reference, path) ->
    @getRepo(path).getAheadBehindCount(reference)

  # Public: Get the cached ahead/behind commit counts for the current branch's
  # upstream branch.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  #
  # Returns an {Object} with the following keys:
  #   * `ahead`  The {Number} of commits ahead.
  #   * `behind` The {Number} of commits behind.
  getCachedUpstreamAheadBehindCount: (path) ->
    @getRepo(path).upstream ? @upstream

  # Public: Returns the git configuration value specified by the key.
  #
  # * `key`  The {String} key for the configuration to lookup.
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  getConfigValue: (key, path) -> @getRepo(path).getConfigValue(key)

  # Public: Returns the origin url of the repository.
  #
  # * `path` (optional) {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  getOriginURL: (path) -> @getConfigValue('remote.origin.url', path)

  # Public: Returns the upstream branch for the current HEAD, or null if there
  # is no upstream branch for the current HEAD.
  #
  # * `path` An optional {String} path in the repo to get this information for,
  #   only needed if the repository contains submodules.
  #
  # Returns a {String} branch name such as `refs/remotes/origin/master`.
  getUpstreamBranch: (path) -> @getRepo(path).getUpstreamBranch()

  # Public: Gets all the local and remote references.
  #
  # * `path` An optional {String} path in the repository to get this information
  #   for, only needed if the repository has submodules.
  #
  # Returns an {Object} with the following keys:
  #  * `heads`   An {Array} of head reference names.
  #  * `remotes` An {Array} of remote reference names.
  #  * `tags`    An {Array} of tag reference names.
  getReferences: (path) -> @getRepo(path).getReferences()

  # Public: Returns the current {String} SHA for the given reference.
  #
  # * `reference` The {String} reference to get the target of.
  # * `path` An optional {String} path in the repo to get the reference target
  #   for. Only needed if the repository contains submodules.
  getReferenceTarget: (reference, path) ->
    @getRepo(path).getReferenceTarget(reference)

  ###
  Section: Reading Status
  ###

  # Public: Returns true if the given path is modified.
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Boolean} that's true if the `path` is modified.
  isPathModified: (path) -> @isStatusModified(@getPathStatus(path))

  # Public: Returns true if the given path is new.
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Boolean} that's true if the `path` is new.
  isPathNew: (path) -> @isStatusNew(@getPathStatus(path))

  # Public: Is the given path ignored?
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Boolean} that's true if the `path` is ignored.
  isPathIgnored: (path) -> @getRepo().isIgnored(@relativize(path))

  # Public: Get the status of a directory in the repository's working directory.
  #
  # * `path` The {String} path to check.
  #
  # Returns a {Number} representing the status. This value can be passed to
  # {::isStatusModified} or {::isStatusNew} to get more information.
  getDirectoryStatus: (directoryPath)  ->
    directoryPath = "#{@relativize(directoryPath)}/"
    directoryStatus = 0
    for statusPath, status of @statuses
      directoryStatus |= status if statusPath.indexOf(directoryPath) is 0
    directoryStatus

  # Public: Get the status of a single path in the repository.
  #
  # * `path` A {String} repository-relative path.
  #
  # Returns a {Number} representing the status. This value can be passed to
  # {::isStatusModified} or {::isStatusNew} to get more information.
  getPathStatus: (path) ->
    repo = @getRepo(path)
    relativePath = @relativize(path)
    currentPathStatus = @statuses[relativePath] ? 0
    pathStatus = repo.getStatus(repo.relativize(path)) ? 0
    pathStatus = 0 if repo.isStatusIgnored(pathStatus)
    if pathStatus > 0
      @statuses[relativePath] = pathStatus
    else
      delete @statuses[relativePath]
    if currentPathStatus isnt pathStatus
      @emitter.emit 'did-change-status', {path, pathStatus}

    pathStatus

  # Public: Get the cached status for the given path.
  #
  # * `path` A {String} path in the repository, relative or absolute.
  #
  # Returns a status {Number} or null if the path is not in the cache.
  getCachedPathStatus: (path) ->
    @statuses[@relativize(path)]

  # Public: Returns true if the given status indicates modification.
  #
  # * `status` A {Number} representing the status.
  #
  # Returns a {Boolean} that's true if the `status` indicates modification.
  isStatusModified: (status) -> @getRepo().isStatusModified(status)

  # Public: Returns true if the given status indicates a new path.
  #
  # * `status` A {Number} representing the status.
  #
  # Returns a {Boolean} that's true if the `status` indicates a new path.
  isStatusNew: (status) -> @getRepo().isStatusNew(status)

  ###
  Section: Retrieving Diffs
  ###

  # Public: Retrieves the number of lines added and removed to a path.
  #
  # This compares the working directory contents of the path to the `HEAD`
  # version.
  #
  # * `path` The {String} path to check.
  #
  # Returns an {Object} with the following keys:
  #   * `added` The {Number} of added lines.
  #   * `deleted` The {Number} of deleted lines.
  getDiffStats: (path) ->
    repo = @getRepo(path)
    repo.getDiffStats(repo.relativize(path))

  # Public: Retrieves the line diffs comparing the `HEAD` version of the given
  # path and the given text.
  #
  # * `path` The {String} path relative to the repository.
  # * `text` The {String} to compare against the `HEAD` contents
  #
  # Returns an {Array} of hunk {Object}s with the following keys:
  #   * `oldStart` The line {Number} of the old hunk.
  #   * `newStart` The line {Number} of the new hunk.
  #   * `oldLines` The {Number} of lines in the old hunk.
  #   * `newLines` The {Number} of lines in the new hunk
  getLineDiffs: (path, text) ->
    # Ignore eol of line differences on windows so that files checked in as
    # LF don't report every line modified when the text contains CRLF endings.
    options = ignoreEolWhitespace: process.platform is 'win32'
    repo = @getRepo(path)
    repo.getLineDiffs(repo.relativize(path), text, options)

  ###
  Section: Checking Out
  ###

  # Public: Restore the contents of a path in the working directory and index
  # to the version at `HEAD`.
  #
  # This is essentially the same as running:
  #
  # ```sh
  #   git reset HEAD -- <path>
  #   git checkout HEAD -- <path>
  # ```
  #
  # * `path` The {String} path to checkout.
  #
  # Returns a {Boolean} that's true if the method was successful.
  checkoutHead: (path) ->
    repo = @getRepo(path)
    headCheckedOut = repo.checkoutHead(repo.relativize(path))
    @getPathStatus(path) if headCheckedOut
    headCheckedOut

  # Public: Checks out a branch in your repository.
  #
  # * `reference` The {String} reference to checkout.
  # * `create`    A {Boolean} value which, if true creates the new reference if
  #   it doesn't exist.
  #
  # Returns a Boolean that's true if the method was successful.
  checkoutReference: (reference, create) ->
    @getRepo().checkoutReference(reference, create)

  ###
  Section: Private
  ###

  # Subscribes to buffer events.
  subscribeToBuffer: (buffer) ->
    getBufferPathStatus = =>
      if bufferPath = buffer.getPath()
        @getPathStatus(bufferPath)

    getBufferPathStatus()
    bufferSubscriptions = new CompositeDisposable
    bufferSubscriptions.add buffer.onDidSave(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidReload(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidChangePath(getBufferPathStatus)
    bufferSubscriptions.add buffer.onDidDestroy =>
      bufferSubscriptions.dispose()
      @subscriptions.remove(bufferSubscriptions)
    @subscriptions.add(bufferSubscriptions)
    return

  # Subscribes to editor view event.
  checkoutHeadForEditor: (editor) ->
    buffer = editor.getBuffer()
    if filePath = buffer.getPath()
      @checkoutHead(filePath)
      buffer.reload()

  # Returns the corresponding {Repository}
  getRepo: (path) ->
    if @repo?
      @repo.submoduleForPath(path) ? @repo
    else
      throw new Error("Repository has been destroyed")

  # Reread the index to update any values that have changed since the
  # last time the index was read.
  refreshIndex: -> @getRepo().refreshIndex()

  # Refreshes the current git status in an outside process and asynchronously
  # updates the relevant properties.
  refreshStatus: ->
    repoPath = @getPath()
    relativeProjectPaths = @project?.getPaths()
      .map (projectPath) => @relativize(projectPath)
      .filter (projectPath) -> projectPath.length > 0 and not path.isAbsolute(projectPath)

    StatusHandlerHelper.refreshStatus(repoPath, relativeProjectPaths).then ({statuses, upstream, branch, submodules}) =>
      statusesUnchanged = _.isEqual(statuses, @statuses) and
                          _.isEqual(upstream, @upstream) and
                          _.isEqual(branch, @branch) and
                          _.isEqual(submodules, @submodules)

      @statuses = statuses
      @upstream = upstream
      @branch = branch
      @submodules = submodules

      for submodulePath, submoduleRepo of @getRepo().submodules
        submoduleRepo.upstream = submodules[submodulePath]?.upstream ? {ahead: 0, behind: 0}

      unless statusesUnchanged
        @emitter.emit 'did-change-statuses'
