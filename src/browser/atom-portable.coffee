fs = require 'fs-plus'
path = require 'path'
{ipcMain} = require 'electron'

module.exports =
class AtomPortable
  @getPortableAtomHomePath: ->
    execDirectoryPath = path.dirname(process.execPath)
    path.join(execDirectoryPath, '..', '.atom')

  @setPortable: (existingAtomHome) ->
    fs.copySync(existingAtomHome, @getPortableAtomHomePath())

  @isPortableInstall: (platform, environmentAtomHome, defaultHome) ->
    return false unless platform in ['linux', 'win32']
    return false if environmentAtomHome
    return false if not fs.existsSync(@getPortableAtomHomePath())
    # currently checking only that the directory exists  and is writable,
    # probably want to do some integrity checks on contents in future
    @isPortableAtomHomePathWritable(defaultHome)

  @isPortableAtomHomePathWritable: (defaultHome) ->
    writable = false
    message = ""
    try
      writePermissionTestFile = path.join(@getPortableAtomHomePath(), "write.test")
      fs.writeFileSync(writePermissionTestFile, "test") if not fs.existsSync(writePermissionTestFile)
      fs.removeSync(writePermissionTestFile)
      writable = true
    catch error
      message = "Failed to use portable Atom home directory (#{@getPortableAtomHomePath()}).  Using the default instead (#{defaultHome}).  #{error.message}"

    ipcMain.on 'check-portable-home-writable', (event) ->
      event.sender.send 'check-portable-home-writable-response', {writable, message}
    writable
