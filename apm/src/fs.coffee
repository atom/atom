_ = require 'underscore-plus'
fs = require 'fs-plus'
ncp = require 'ncp'
rm = require 'rimraf'
wrench = require 'wrench'

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
    rm destinationPath, (error) ->
      if error?
        callback(error)
      else
        ncp(sourcePath, destinationPath, callback)

module.exports = _.extend({}, fs, fsAdditions)
