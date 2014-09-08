fs = require 'fs-plus'
_ = require 'underscore-plus'
wrench = require 'wrench'
ncp = require 'ncp'

fsAdditions =
  list: (directoryPath) ->
    if fs.isDirectorySync(directoryPath)
      try
        fs.readdirSync(directoryPath)
      catch e
        []
    else
      []

  listRecursive: (directoryPath) ->
    wrench.readdirSyncRecursive(directoryPath)

  cp: (sourcePath, destinationPath, callback) ->
    fs.removeSync(destinationPath)
    ncp(sourcePath, destinationPath, callback)

module.exports = _.extend({}, fs, fsAdditions)
