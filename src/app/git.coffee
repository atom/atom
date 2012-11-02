module.exports =
class Git

  @isPathIgnored: (path) ->
    return false unless path
    repo = new Git(path)
    repo.isIgnored(repo.relativize(path))

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

  getPath: -> @repo.getPath()

  getWorkingDirectory: ->
    repoPath = @repo.getPath()
    if repoPath
      repoPath.substring(0, repoPath.length - 5)

  getHead: ->
    @repo.getHead() or ''

  isIgnored: (path) ->
    path and @repo.isIgnored(path)

  isModified: (path) ->
    statusFlags = @repo.getStatus(@relativize(path))
    modifiedFlags = @statusFlags.working_dir_new |
                    @statusFlags.working_dir_modified |
                    @statusFlags.working_dir_delete |
                    @statusFlags.working_dir_typechange

    (statusFlags & modifiedFlags) > 0

  relativize: (path) ->
    return path unless path
    workingDirectory = @getWorkingDirectory()
    if workingDirectory and path.indexOf(workingDirectory) is 0
      path.substring(workingDirectory.length)

  getShortHead: ->
    head = @getHead()
    return head.substring(11) if head.indexOf('refs/heads/') is 0
    return head.substring(10) if head.indexOf('refs/tags/') is 0
    return head.substring(13) if head.indexOf('refs/remotes/') is 0
    return head.substring(0, 7) if head.match(/[a-fA-F0-9]{40}/)
    return head
