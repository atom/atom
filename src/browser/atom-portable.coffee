fs = require 'fs-plus'
path = require 'path'
ipc = require 'ipc'

module.exports =
class AtomPortable
  @portableAtomHomePath: ->
    execDirectoryPath = path.dirname(process.execPath)
    return path.join(execDirectoryPath, '..', '.atom')

  @setPortable: (existingAtomHome) ->
    fs.copySync(existingAtomHome, @portableAtomHomePath())

  @isPortableInstall: (platform, environmentAtomHome) ->
    return false unless platform is 'win32'
    return false if environmentAtomHome

    return false if not fs.existsSync(@portableAtomHomePath())

    # currently checking only that the directory exists  and is writable,
    # probably want to do some integrity checks on contents in future
    return @portableAtomHomePathWritable()

  @portableAtomHomePathWritable: ->
    writable = false
    message = ""
    try
      writePermissionTestFile = path.join(@portableAtomHomePath(), "write.test")
      fs.writeFileSync(writePermissionTestFile, "test") if not fs.existsSync(writePermissionTestFile)
      fs.removeSync(writePermissionTestFile)
      writable = true
    catch error
      message = "Failed to use portable Atom home directory.  Using the default instead."
      message = "Portable Atom home directory (#{@portableAtomHomePath()}) is not writable.  Using the default instead." if error.code == "EPERM"

    ipc.on 'check-portable-home-writable', (event, arg) ->
      event.sender.send 'check-portable-home-writable-response', {writable, message}
    return writable
