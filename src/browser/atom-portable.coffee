fs = require 'fs-plus'
path = require 'path'

module.exports =
class AtomPortable
  @portableAtomHomePath: ->
    execDirectoryPath = path.dirname(process.execPath)
    return path.join(execDirectoryPath, "../.atom")
  @isPortableInstall: (platform, environmentAtomHome) ->
    return false unless platform is 'win32'
    return false if environmentAtomHome

    # currently checking only that the directory exists, probably want to do
    # some integrity checks on contents and make sure it's writable in future
    return fs.existsSync(@portableAtomHomePath())
