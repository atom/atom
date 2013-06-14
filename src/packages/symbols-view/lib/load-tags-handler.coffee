ctags = require 'ctags'
fsUtils = require 'fs-utils'
path = require 'path'

getTagsFile = (directoryPath) ->
  tagsFile = path.join(directoryPath, "tags")
  return tagsFile if fsUtils.isFileSync(tagsFile)

  tagsFile = path.join(directoryPath, "TAGS")
  return tagsFile if fsUtils.isFileSync(tagsFile)

module.exports = (directoryPath) ->
  tagsFilePath = getTagsFile(directoryPath)
  if tagsFilePath
    ctags.getTags(tagsFilePath)
  else
    []
