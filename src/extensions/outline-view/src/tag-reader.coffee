fs = require 'fs'
$ = require 'jquery'

module.exports =

getTagsFile: (editor) ->
  project = editor.rootView().project
  tagsFile = project.resolve("tags") or project.resolve("TAGS")
  return tagsFile if fs.isFile(tagsFile)

find: (editor) ->
  word = editor.getTextInRange(editor.getCursor().getCurrentWordBufferRange())
  return [] unless word.length > 0

  tagsFile = @getTagsFile(editor)
  return [] unless tagsFile

  $tags.find(tagsFile, word) or []

getAllTags: (editor, callback) ->
  deferred = $.Deferred()
  tagsFile = @getTagsFile(editor)
  if tagsFile
    $tags.getAllTagsAsync tagsFile, (tags) =>
      deferred.resolve(tags)
  else
    deferred.resolve([])
  deferred.promise()
