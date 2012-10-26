module.exports =
class Git

  @isPathIgnored: (path) ->
    return false unless path
    repo = new Git(path)
    repo.isIgnored(repo.relativize(path))

  constructor: (path) ->
    @repo = new GitRepository(path)

  getPath: -> @repo.getPath()

  getWorkingDirectory: ->
    repoPath = @repo.getPath()
    if repoPath
      repoPath.substring(0, repoPath.length - 5)

  getHead: -> @repo.getHead() || ''

  isIgnored: (path) ->
    path and @repo.isIgnored(path)

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
