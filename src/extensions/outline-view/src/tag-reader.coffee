fs = require 'fs'

module.exports =

find: (editor) ->
  word = editor.getTextInRange(editor.getCursor().getCurrentWordBufferRange())
  return [] unless word.length > 0

  project = editor.rootView().project
  tagsFile = project.resolve("tags") or project.resolve("TAGS")
  return [] unless fs.isFile(tagsFile)

  $tags.find(tagsFile, word) or []
