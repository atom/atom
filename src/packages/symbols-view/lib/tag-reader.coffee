fsUtils = require 'fs-utils'
$ = require 'jquery'
Task = require 'task'
ctags = require 'ctags'

handlerPath = require.resolve('./load-tags-handler')

module.exports =
getTagsFile: (project) ->
  tagsFile = project.resolve("tags") or project.resolve("TAGS")
  return tagsFile if fsUtils.isFileSync(tagsFile)

find: (editor) ->
  word = editor.getTextInRange(editor.getCursor().getCurrentWordBufferRange())
  return [] unless word.length > 0

  tagsFile = @getTagsFile(project)
  return [] unless tagsFile

  ctags.findTags(tagsFile, word)

getAllTags: (project, callback) ->
  deferred = $.Deferred()

  task = new Task(handlerPath)
  task.start project.getPath(), (tags) ->
    deferred.resolve(tags)
    task.terminate()

  deferred.promise()
