Task = require 'task'
_ = require 'underscore'

module.exports =
class RepositoryStatusTask extends Task

  constructor: (@repo) ->
    super('repository-status-handler')

  started: ->
    @callWorkerMethod('loadStatuses', @repo.getPath())

  statusesLoaded: (statuses) ->
    @done()
    unless _.isEqual(statuses, @repo.statuses)
      @repo.statuses = statuses
      @repo.trigger 'statuses-changed'
