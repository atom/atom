fs = require 'fs-plus'
_ = require 'underscore-plus'
runas = null
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

  cp: (sourcePath, destinationPath, options) ->
    wrench.copyDirSyncRecursive(sourcePath, destinationPath, options)

  safeSymlinkSync: (source, target) ->
    if process.platform is 'win32'
      runas ?= require 'runas'
      runas('cmd', ['/K', "mklink /d \"#{target}\" \"#{source}\" & exit"], hide: true)
    else
      fs.symlinkSync(source, target)

module.exports = _.extend({}, fs, fsAdditions)
