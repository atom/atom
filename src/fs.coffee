fs = require 'fs'
_ = require 'underscore'
rimraf = require 'rimraf'

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

  rm: (pathToRemove) ->
    rimraf.sync(pathToRemove)

module.exports = _.extend(fsAdditions, fs)
