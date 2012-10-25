module.exports =
class Git

  @open: (path) ->
    repoPath = $git.getRepositoryPath(path)
    new Git(repoPath) if repoPath

  constructor: (@repoPath) ->
    @repo = new GitRepository(@repoPath)

  getHead: ->
    head = @repo.getHead()
    return '' unless head
    return head.substring(11) if head.indexOf('refs/heads/') is 0
    return head.substring(10) if head.indexOf('refs/tags/') is 0
    return head.substring(13) if head.indexOf('refs/remotes/') is 0
