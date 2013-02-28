_ = require 'underscore'
Subscriber = require 'subscriber'
GitRepository = require 'git-repository'

module.exports =
class Git

  @open: (path, options) ->
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

  constructor: (path, options={}) ->
    @repo = GitRepository.open(path)
    refreshIndexOnFocus = options.refreshIndexOnFocus ? true
    if refreshIndexOnFocus
      $ = require 'jquery'
      @subscribe $(window), 'focus', => @refreshIndex()

  getRepo: ->
    unless @repo?
      throw new Error("Repository has been destroyed")
    @repo

  refreshIndex: -> @getRepo().refreshIndex()

  getPath: -> @getRepo().getPath()

  destroy: ->
    @getRepo().destroy()
    @repo = null
    @unsubscribe()

  getWorkingDirectory: ->
    repoPath = @getPath()
    repoPath?.substring(0, repoPath.length - 6)

  getHead: ->
    @getRepo().getHead() ? ''

  getPathStatus: (path) ->
    pathStatus = @getRepo().getStatus(@relativize(path))

  isPathIgnored: (path) ->
    @getRepo().isIgnored(@relativize(path))

  isStatusModified: (status) ->
    modifiedFlags = @statusFlags.working_dir_modified |
                    @statusFlags.working_dir_delete |
                    @statusFlags.working_dir_typechange |
                    @statusFlags.index_modified |
                    @statusFlags.index_deleted |
                    @statusFlags.index_typechange
    (status & modifiedFlags) > 0

  isPathModified: (path) ->
    @isStatusModified(@getPathStatus(path))

  isStatusNew: (status) ->
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
    @getRepo().checkoutHead(@relativize(path))

  getDiffStats: (path) ->
    @getRepo().getDiffStats(@relativize(path)) ? added: 0, deleted: 0

  isSubmodule: (path) ->
    @getRepo().isSubmodule(@relativize(path))

_.extend Git.prototype, Subscriber
