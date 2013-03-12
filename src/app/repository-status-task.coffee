Task = require 'task'
_ = nodeRequire 'underscore'

module.exports =
class RepositoryStatusTask extends Task
  constructor: (@repo) ->
    super('repository-status-handler')

  started: ->
    @callWorkerMethod('loadStatuses', @repo.getPath())

  statusesLoaded: ({statuses, upstream}) ->
    @done()
    statusesUnchanged = _.isEqual(statuses, @repo.statuses) and _.isEqual(upstream, @repo.upstream)
    @repo.statuses = statuses
    @repo.upstream = upstream
    @repo.trigger 'statuses-changed' unless statusesUnchanged
