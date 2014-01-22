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
  getInstallDirectory: ->
    "/usr/local/bin"

  install: (commandPath, callback) ->
    return unless process.platform is 'darwin'

    commandName = path.basename(commandPath, path.extname(commandPath))
    directory = @getInstallDirectory()
    if fs.existsSync(directory)
      destinationPath = path.join(directory, commandName)
      unlinkCommand destinationPath, (error) =>
        if error?
          error = new Error "Could not remove file at #{destinationPath}." if error
          callback?(error)
        else
          symlinkCommand commandPath, destinationPath, (error) =>
            error = new Error "Failed to symlink #{commandPath} to #{destinationPath}." if error
            callback?(error)
    else
      error = new Error "Directory '#{directory} doesn't exist."
      callback?(error)

  installAtomCommand: (callback) ->
    resourcePath = atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'atom.sh')
    @install commandPath, callback

  installApmCommand: (callback) ->
    resourcePath = atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'apm', 'node_modules', '.bin', 'apm')
    @install commandPath, callback
