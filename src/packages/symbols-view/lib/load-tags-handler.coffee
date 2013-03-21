ctags = require 'ctags'
fs = require 'fs-utils'

module.exports =
  getTagsFile: (path) ->
    tagsFile = fs.join(path, "tags")
    return tagsFile if fs.isFile(tagsFile)

    tagsFile = fs.join(path, "TAGS")
    return tagsFile if fs.isFile(tagsFile)

  loadTags: (path) ->
    tagsFile = @getTagsFile(path)
    if tagsFile
      callTaskMethod("tagsLoaded", ctags.getTags(tagsFile))
    else
      callTaskMethod("tagsLoaded", [])
