const fs = require('fs-plus')
const path = require('path')
const {ipcMain} = require('electron')

module.exports = class AtomPortable {
  static getPortableAtomHomePath () {
    const execDirectoryPath = path.dirname(process.execPath)
    return path.join(execDirectoryPath, '..', '.atom')
  }

  static setPortable (existingAtomHome) {
    fs.copySync(existingAtomHome, this.getPortableAtomHomePath())
  }

  static isPortableInstall (platform, environmentAtomHome, defaultHome) {
    if (!['linux', 'win32'].includes(platform)) {
      return false
    }

    if (environmentAtomHome) {
      return false
    }

    if (!fs.existsSync(this.getPortableAtomHomePath())) {
      return false
    }

    // Currently checking only that the directory exists and is writable,
    // probably want to do some integrity checks on contents in future.
    return this.isPortableAtomHomePathWritable(defaultHome)
  }

  static isPortableAtomHomePathWritable (defaultHome) {
    let writable = false
    let message = ''
    try {
      const writePermissionTestFile = path.join(this.getPortableAtomHomePath(), 'write.test')

      if (!fs.existsSync(writePermissionTestFile)) {
        fs.writeFileSync(writePermissionTestFile, 'test')
      }

      fs.removeSync(writePermissionTestFile)
      writable = true
    } catch (error) {
      message = `Failed to use portable Atom home directory (${this.getPortableAtomHomePath()}). Using the default instead (${defaultHome}). ${error.message}.`
    }

    ipcMain.on('check-portable-home-writable', function (event) {
      event.sender.send('check-portable-home-writable-response', {
        writable: writable,
        message: message
      })
    })

    return writable
  }
}
