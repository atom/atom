fs = require 'fs'

_ = require 'underscore'
mkdirp = require 'mkdirp'
rimraf = require 'rimraf'
wrench = require 'wrench'

fsAdditions =
  isDirectory: (directoryPath) ->
    try
      fs.statSync(directoryPath).isDirectory()
    catch e
      false

  isFile: (filePath) ->
    try
      fs.statSync(filePath).isFile()
    catch e
      false

  isLink: (filePath) ->
    try
      fs.lstatSync(filePath).isSymbolicLink()
    catch e
      false

  list: (directoryPath) ->
    if @isDirectory(directoryPath)
      try
        fs.readdirSync(directoryPath)
      catch e
        []
    else
      []

  listRecursive: (directoryPath) ->
    wrench.readdirSyncRecursive(directoryPath)

  rm: (pathToRemove) ->
    rimraf.sync(pathToRemove)

  mkdir: (directoryPath) ->
    mkdirp.sync(directoryPath)

  cp: (sourcePath, destinationPath, options) ->
    wrench.copyDirSyncRecursive(sourcePath, destinationPath, options)

module.exports = _.extend(fsAdditions, fs)
