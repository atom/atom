path = require 'path'
fs = require 'fs'

module.exports =
  getHomeDirectory: ->
    if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME

  getAtomDirectory: ->
    process.env.ATOM_HOME ? path.join(@getHomeDirectory(), '.atom')

  getResourcePath: ->
    process.env.ATOM_RESOURCE_PATH ? '/Applications/Atom.app/Contents/Resources/app'

  getNodeUrl: ->
    process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/atom-shell/dist'

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? 'http://atom.iriscouch.com/registry/_design/apm/_view/atom_packages'

  getNodeVersion: ->
    process.env.ATOM_NODE_VERSION ? '0.10.15'

  getUserConfigPath: ->
    path.resolve(__dirname, '..', '.apmrc')

  isWin32: ->
    !!process.platform.match(/^win/)

  isWindows64Bit: ->
    fs.existsSync "C:\\Windows\\SysWow64\\Notepad.exe"

  x86ProgramFilesDirectory: ->
    process.env["ProgramFiles(x86)"] || process.env["ProgramFiles"]

  isVs2010Installed: ->
    return false unless isWin32()

    vsPath = path.join x86ProgramFilesDirectory(), "Microsoft Visual Studio 10.0", "Common7", "IDE", "devenv.exe"
    fs.existsSync vsPath

  isVs2012Installed: ->
    return false unless isWin32()

    vsPath = path.join x86ProgramFilesDirectory(), "Microsoft Visual Studio 11.0", "Common7", "IDE", "devenv.exe"
    fs.existsSync vsPath
