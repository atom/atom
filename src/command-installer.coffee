path = require 'path'
fs = require 'fs-plus'
runas = null # defer until used

symlinkCommand = (sourcePath, destinationPath, callback) ->
  fs.unlink destinationPath, (error) ->
    if error? and error?.code isnt 'ENOENT'
      callback(error)
    else
      fs.makeTree path.dirname(destinationPath), (error) ->
        if error?
          callback(error)
        else
          fs.symlink sourcePath, destinationPath, callback

symlinkCommandWithPrivilegeSync = (sourcePath, destinationPath) ->
  runas ?= require 'runas'
  if runas('/bin/rm', ['-f', destinationPath], admin: true) isnt 0
    throw new Error("Failed to remove '#{destinationPath}'")

  if runas('/bin/mkdir', ['-p', path.dirname(destinationPath)], admin: true) isnt 0
    throw new Error("Failed to create directory '#{destinationPath}'")

  if runas('/bin/ln', ['-s', sourcePath, destinationPath], admin: true) isnt 0
    throw new Error("Failed to symlink '#{sourcePath}' to '#{destinationPath}'")

module.exports =
  getInstallDirectory: ->
    "/usr/local/bin"

  installShellCommandsInteractively: ->
    showErrorDialog = (error) ->
      atom.confirm
        message: "Failed to install shell commands"
        detailedMessage: error.message

    @installAtomCommand true, (error) =>
      if error?
        showErrorDialog(error)
      else
        @installApmCommand true, (error) ->
          if error?
            showErrorDialog(error)
          else
            atom.confirm
              message: "Commands installed."
              detailedMessage: "The shell commands `atom` and `apm` are installed."

  installAtomCommand: (askForPrivilege, callback) ->
    commandPath = path.join(process.resourcesPath, 'app', 'atom.sh')
    @createSymlink commandPath, askForPrivilege, callback

  installApmCommand: (askForPrivilege, callback) ->
    commandPath = path.join(process.resourcesPath, 'app', 'apm', 'node_modules', '.bin', 'apm')
    @createSymlink commandPath, askForPrivilege, callback

  createSymlink: (commandPath, askForPrivilege, callback) ->
    return unless process.platform is 'darwin'

    commandName = path.basename(commandPath, path.extname(commandPath))
    destinationPath = path.join(@getInstallDirectory(), commandName)

    fs.readlink destinationPath, (error, realpath) ->
      if realpath is commandPath
        callback()
        return

      symlinkCommand commandPath, destinationPath, (error) ->
        if askForPrivilege and error?.code is 'EACCES'
          try
            error = null
            symlinkCommandWithPrivilegeSync(commandPath, destinationPath)
          catch error

        callback?(error)
