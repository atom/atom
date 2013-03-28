Task = require 'task'

module.exports =
class LoadTagsTask extends Task
  constructor: (@callback) ->
    super('symbols-view/lib/load-tags-handler')

  started: ->
    @callWorkerMethod('loadTags', project.getPath())

  tagsLoaded: (tags) ->
    @done()
    @callback(tags)
