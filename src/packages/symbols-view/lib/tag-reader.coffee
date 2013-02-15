fs = require 'fs'
$ = require 'jquery'

module.exports =

getTagsFile: (project) ->
  tagsFile = project.resolve("tags") or project.resolve("TAGS")
  return tagsFile if fs.isFile(tagsFile)

find: (editor) ->
  word = editor.getTextInRange(editor.getCursor().getCurrentWordBufferRange())
  return [] unless word.length > 0

  tagsFile = @getTagsFile(rootView.project)
  return [] unless tagsFile

  $tags.find(tagsFile, word) or []

getAllTags: (project, callback) ->
  deferred = $.Deferred()
  tagsFile = @getTagsFile(project)
  if tagsFile
    $tags.getAllTagsAsync tagsFile, (tags) =>
      deferred.resolve(tags)
  else
    deferred.resolve([])
  deferred.promise()
