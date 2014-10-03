path = require 'path'
_ = require 'underscore-plus'
async = require 'async'
fs = require 'fs-plus'
mkdirp = require 'mkdirp'
runas = require 'runas'

symlinkCommand = (sourcePath, destinationPath, callback) ->
  fs.unlink destinationPath, (error) ->
    if error? and error?.code != 'ENOENT'
      callback(error)
    else
      mkdirp path.dirname(destinationPath), (error) ->
        if error?
          callback(error)
        else
          fs.symlink sourcePath, destinationPath, callback

symlinkCommandWithPrivilegeSync = (sourcePath, destinationPath) ->
  if runas('/bin/rm', ['-f', destinationPath], admin: true) != 0
    throw new Error("Failed to remove '#{destinationPath}'")

  if runas('/bin/mkdir', ['-p', path.dirname(destinationPath)], admin: true) != 0
    throw new Error("Failed to create directory '#{destinationPath}'")

  if runas('/bin/ln', ['-s', sourcePath, destinationPath], admin: true) != 0
    throw new Error("Failed to symlink '#{sourcePath}' to '#{destinationPath}'")

module.exports =
  getInstallDirectory: ->
    "/usr/local/bin"

  installShellCommandsInteractively: ->
    showErrorDialog = (error) ->
      atom.confirm
        message: "Failed to install shell commands"
        detailedMessage: error.message

    resourcePath = atom.getLoadSettings().resourcePath
    @installAtomCommand resourcePath, true, (error) =>
      if error?
        showErrorDialog(error)
      else
        @installApmCommand resourcePath, true, (error) ->
          if error?
            showErrorDialog(error)
          else
            atom.confirm
              message: "Commands installed."
              detailedMessage: "The shell commands `atom` and `apm` are installed."

  installAtomCommand: (resourcePath, askForPrivilege, callback) ->
    commandPath = path.join(resourcePath, 'atom.sh')
    @createSymlink commandPath, askForPrivilege, callback

  installApmCommand: (resourcePath, askForPrivilege, callback) ->
    commandPath = path.join(resourcePath, 'apm', 'node_modules', '.bin', 'apm')
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
