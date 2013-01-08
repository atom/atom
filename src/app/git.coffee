$ = require 'jquery'

module.exports =
class Git

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

  constructor: (path) ->
    @repo = new GitRepository(path)
    $(window).on 'focus', => @refreshIndex()

  refreshIndex: -> @repo.refreshIndex()

  getPath: -> @repo.getPath()

  getWorkingDirectory: ->
    repoPath = @getPath()
    repoPath?.substring(0, repoPath.length - 6)

  getHead: ->
    @repo.getHead() or ''

  getPathStatus: (path) ->
    pathStatus = @repo.getStatus(@relativize(path))

  isPathIgnored: (path) ->
    @repo.isIgnored(@relativize(path))

  isPathModified: (path) ->
    modifiedFlags = @statusFlags.working_dir_modified |
                    @statusFlags.working_dir_delete |
                    @statusFlags.working_dir_typechange |
                    @statusFlags.index_modified |
                    @statusFlags.index_deleted |
                    @statusFlags.index_typechange
    (@getPathStatus(path) & modifiedFlags) > 0

  isPathNew: (path) ->
    newFlags = @statusFlags.working_dir_new |
               @statusFlags.index_new
    (@getPathStatus(path) & newFlags) > 0

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
    @repo.checkoutHead(@relativize(path))

  getDiffStats: (path) ->
    @repo.getDiffStats(@relativize(path)) or added: 0, deleted: 0

  isSubmodule: (path) ->
    @repo.isSubmodule(@relativize(path))
