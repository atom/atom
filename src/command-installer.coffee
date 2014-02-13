path = require 'path'
_ = require 'underscore-plus'
async = require 'async'
fs = require 'fs-plus'
mkdirp = require 'mkdirp'
runas = require 'runas'

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

symlinkCommandWithPrivilegeSync = (sourcePath, destinationPath) ->
  runas('/bin/mkdir', ['-p', path.dirname(destinationPath)], admin: true)
  runas('/bin/ln', ['-s', sourcePath, destinationPath], admin: true) is 0

unlinkCommand = (destinationPath, callback) ->
  fs.unlink destinationPath, (error) ->
    if error? and error.code isnt 'ENOENT'
      callback(error)
    else
      callback()

unlinkCommandWithPrivilegeSync = (destinationPath) ->
  runas('/bin/rm', ['-f', destinationPath], admin: true) is 0

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
        # Retry with privilige escalation.
        if error?.code is 'EACCES' and unlinkCommandWithPrivilegeSync(destinationPath)
          error = null

        if error?
          error = new Error "Could not remove file at #{destinationPath}."
          callback?(error)
        else
          symlinkCommand commandPath, destinationPath, (error) =>
            # Retry with privilige escalation.
            if error?.code is 'EACCES' and symlinkCommandWithPrivilegeSync(commandPath, destinationPath)
              error = null

            error = new Error "Failed to symlink #{commandPath} to #{destinationPath}." if error?
            callback?(error)
    else
      error = new Error "Directory '#{directory} doesn't exist."
      callback?(error)

  installAtomCommand: (resourcePath, callback) ->
    commandPath = path.join(resourcePath, 'atom.sh')
    @install commandPath, callback

  installApmCommand: (resourcePath, callback) ->
    commandPath = path.join(resourcePath, 'apm', 'node_modules', '.bin', 'apm')
    @install commandPath, callback
