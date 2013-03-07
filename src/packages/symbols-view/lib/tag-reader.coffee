fs = require 'fs'
$ = require 'jquery'
LoadTagsTask = require './load-tags-task'
ctags = nodeRequire 'ctags'

module.exports =

getTagsFile: (project) ->
  tagsFile = project.resolve("tags") or project.resolve("TAGS")
  return tagsFile if fs.isFile(tagsFile)

find: (editor) ->
  word = editor.getTextInRange(editor.getCursor().getCurrentWordBufferRange())
  return [] unless word.length > 0

  tagsFile = @getTagsFile(project)
  return [] unless tagsFile

  ctags.findTag(tagsFile, word)

getAllTags: (project, callback) ->
  deferred = $.Deferred()
  callback = (tags=[]) =>
    deferred.resolve(tags)
  new LoadTagsTask(callback).start()
  deferred.promise()
