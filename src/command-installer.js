const path = require('path')
const fs = require('fs-plus')

module.exports =
class CommandInstaller {
  constructor (applicationDelegate) {
    this.applicationDelegate = applicationDelegate
  }

  initialize (appVersion) {
    this.appVersion = appVersion
  }

  getInstallDirectory () {
    return '/usr/local/bin'
  }

  getResourcesDirectory () {
    return process.resourcesPath
  }

  installShellCommandsInteractively () {
    const showErrorDialog = (error) => {
      this.applicationDelegate.confirm({
        message: 'Failed to install shell commands',
        detailedMessage: error.message
      })
    }

    this.installAtomCommand(true, error => {
      if (error) return showErrorDialog(error)
      this.installApmCommand(true, error => {
        if (error) return showErrorDialog(error)
        this.applicationDelegate.confirm({
          message: 'Commands installed.',
          detailedMessage: 'The shell commands `atom` and `apm` are installed.'
        })
      })
    })
  }

  installAtomCommand (askForPrivilege, callback) {
    this.installCommand(
      path.join(this.getResourcesDirectory(), 'app', 'atom.sh'),
      this.appVersion.includes('beta') ? 'atom-beta' : 'atom',
      askForPrivilege,
      callback
    )
  }

  installApmCommand (askForPrivilege, callback) {
    this.installCommand(
      path.join(this.getResourcesDirectory(), 'app', 'apm', 'node_modules', '.bin', 'apm'),
      this.appVersion.includes('beta') ? 'apm-beta' : 'apm',
      askForPrivilege,
      callback
    )
  }

  installCommand (commandPath, commandName, askForPrivilege, callback) {
    if (process.platform !== 'darwin') return callback()

    const destinationPath = path.join(this.getInstallDirectory(), commandName)

    fs.readlink(destinationPath, (error, realpath) => {
      if (error && error.code !== 'ENOENT') return callback(error)
      if (realpath === commandPath) return callback()
      this.createSymlink(fs, commandPath, destinationPath, error => {
        if (error && error.code === 'EACCES' && askForPrivilege) {
          const fsAdmin = require('fs-admin')
          this.createSymlink(fsAdmin, commandPath, destinationPath, callback)
        } else {
          callback(error)
        }
      })
    })
  }

  createSymlink (fs, sourcePath, destinationPath, callback) {
    fs.unlink(destinationPath, (error) => {
      if (error && error.code !== 'ENOENT') return callback(error)
      fs.makeTree(path.dirname(destinationPath), (error) => {
        if (error) return callback(error)
        fs.symlink(sourcePath, destinationPath, callback)
      })
    })
  }
}
