ctags = require 'ctags'
fsUtils = require 'fs-utils'
path = require 'path'

module.exports =
  getTagsFile: (tagsFilePath) ->
    tagsFile = path.join(tagsFilePath, "tags")
    return tagsFile if fsUtils.isFileSync(tagsFile)

    tagsFile = path.join(tagsFilePath, "TAGS")
    return tagsFile if fsUtils.isFileSync(tagsFile)

  loadTags: (tagsFilePath) ->
    tagsFile = @getTagsFile(tagsFilePath)
    if tagsFile
      callTaskMethod("tagsLoaded", ctags.getTags(tagsFile))
    else
      callTaskMethod("tagsLoaded", [])
