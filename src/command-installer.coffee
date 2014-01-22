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

  install: (commandPath) ->
    commandName = path.basename(commandPath, path.extname(commandPath))
    directory = @getInstallDirectory()
    if fs.existsSync(directory)
      destinationPath = path.join(directory, commandName)
      unlinkCommand destinationPath, (error) =>
        if error?
          @displayError(error, commandPath)
        else
          symlinkCommand commandPath, destinationPath, (error) =>
            @displayError(error, commandPath) if error
    else
      error = new Error("No destination directory exists to install")
      @displayError(error, commandPath) if error

  displayError: (error, commandPath) ->
    atom.confirm
      type: 'warning'
      message: "Failed to install `#{commandPath}` binary"
      detailedMessage: "#{error.message}\n\nRun 'sudo ln -s #{commandPath} #{path.join(@getInstallDirectory(), path.basename(commandPath))}' to install."

  installAtomCommand: ->
    resourcePath = atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'atom.sh')
    @install commandPath

  installApmCommand: ->
    resourcePath = atom.getLoadSettings().resourcePath
    commandPath = path.join(resourcePath, 'apm', 'node_modules', '.bin', 'apm')
    @install commandPath
