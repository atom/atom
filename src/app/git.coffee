module.exports =
class Git

  constructor: (path) ->
    @repo = new GitRepository(path)

  getPath: -> @repo.getPath()

  getHead: -> @repo.getHead() || ''

  getShortHead: ->
    head = @getHead()
    return head.substring(11) if head.indexOf('refs/heads/') is 0
    return head.substring(10) if head.indexOf('refs/tags/') is 0
    return head.substring(13) if head.indexOf('refs/remotes/') is 0
    return head.substring(0, 7) if head.match(/[a-fA-F0-9]{40}/)
    return head
