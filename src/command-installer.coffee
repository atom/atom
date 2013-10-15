path = require 'path'
fs = require 'fs'
_ = require 'underscore-plus'
async = require 'async'
mkdirp = require 'mkdirp'
fsUtils = require './fs-utils'

symlinkCommand = (sourcePath, destinationPath, callback) ->
  mkdirp path.dirname(destinationPath), (error) ->
    if error?
      callback(error)
    else
      fs.symlink sourcePath, destinationPath, (error) ->
        if error?
          callback(error)
        else
          fs.chmod(destinationPath, 0o755, callback)

unlinkCommand = (destinationPath, callback) ->
  fs.unlink destinationPath, (error) ->
    if error? and error.code isnt 'ENOENT'
      callback(error)
    else
      callback()

module.exports =
  findInstallDirectory: (callback) ->
    directories = ['/opt/boxen', '/opt/github', '/usr/local']
    async.detect(directories, fsUtils.isDirectory, callback)

  install: (commandPath, commandName, callback) ->
    if not commandName? or _.isFunction(commandName)
      callback = commandName
      commandName = path.basename(commandPath, path.extname(commandPath))

    installCallback = (error) ->
      if error?
        console.warn "Failed to install `#{commandName}` binary", error
      callback?(error)

    @findInstallDirectory (directory) ->
      if directory?
        destinationPath = path.join(directory, 'bin', commandName)
        unlinkCommand destinationPath, (error) ->
          if error?
            installCallback(error)
          else
            symlinkCommand(commandPath, destinationPath, installCallback)
      else
        installCallback(new Error("No destination directory exists to install"))
