ctags = require 'ctags'
fsUtils = require 'fs-utils'

module.exports =
  getTagsFile: (path) ->
    tagsFile = fsUtils.join(path, "tags")
    return tagsFile if fsUtils.isFile(tagsFile)

    tagsFile = fsUtils.join(path, "TAGS")
    return tagsFile if fsUtils.isFile(tagsFile)

  loadTags: (path) ->
    tagsFile = @getTagsFile(path)
    if tagsFile
      callTaskMethod("tagsLoaded", ctags.getTags(tagsFile))
    else
      callTaskMethod("tagsLoaded", [])
