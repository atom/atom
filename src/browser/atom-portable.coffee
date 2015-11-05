fs = require 'fs-plus'
path = require 'path'
ipc = require 'ipc'

module.exports =
class AtomPortable
  @getPortableAtomHomePath: (platform) ->
    # OS X has a deeper path for the executable in the application package, so need a different
    # relative path to find the portable home directory
    return path.join(process.resourcesPath, '..', '..', '..', '.atom') if platform is 'darwin'
    execDirectoryPath = path.dirname(process.execPath)
    path.join(execDirectoryPath, '..', '.atom')

  @setPortable: (platform, existingAtomHome) ->
    fs.copySync(existingAtomHome, @getPortableAtomHomePath(platform))

  @isPortableInstall: (platform, environmentAtomHome, defaultHome) ->
    return false if environmentAtomHome
    return false if not fs.existsSync(@getPortableAtomHomePath platform)
    # currently checking only that the directory exists  and is writable,
    # probably want to do some integrity checks on contents in future

    @isPortableAtomHomePathWritable(defaultHome)

  @isPortableAtomHomePathWritable: (platform, defaultHome) ->
    writable = false
    message = ""
    try
      writePermissionTestFile = path.join(@getPortableAtomHomePath(platform), "write.test")
      fs.writeFileSync(writePermissionTestFile, "test") if not fs.existsSync(writePermissionTestFile)
      fs.removeSync(writePermissionTestFile)
      writable = true
    catch error
      message = "Failed to use portable Atom home directory (#{@getPortableAtomHomePath platform}).  Using the default instead (#{defaultHome}).  #{error.message}"

    ipc.on 'check-portable-home-writable', (event) ->
      event.sender.send 'check-portable-home-writable-response', {writable, message}
    writable
