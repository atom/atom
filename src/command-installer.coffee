path = require 'path'
_ = require 'underscore-plus'
async = require 'async'
fs = require 'fs-plus'
mkdirp = require 'mkdirp'

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
    async.detect(directories, fs.isDirectory, callback)

  install: (commandPath, commandName, callback) ->
    if not commandName? or _.isFunction(commandName)
      callback = commandName
      commandName = path.basename(commandPath, path.extname(commandPath))

    installCallback = (error, sourcePath, destinationPath) ->
      if error?
        console.warn "Failed to install `#{commandName}` binary", error
      callback?(error, sourcePath, destinationPath)

    @findInstallDirectory (directory) ->
      if directory?
        destinationPath = path.join(directory, 'bin', commandName)
        unlinkCommand destinationPath, (error) ->
          if error?
            installCallback(error)
          else
            symlinkCommand commandPath, destinationPath, (error) ->
              installCallback(error, commandPath, destinationPath)
      else
        installCallback(new Error("No destination directory exists to install"))

  installAtomCommand: (resourcePath, callback) ->
    if _.isFunction(resourcePath)
      callback = resourcePath
      resourcePath = null

    resourcePath ?= atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'atom.sh')
    @install(commandPath, callback)

  installApmCommand: (resourcePath, callback) ->
    if _.isFunction(resourcePath)
      callback = resourcePath
      resourcePath = null

    resourcePath ?= atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'node_modules', '.bin', 'apm')
    @install(commandPath, callback)
