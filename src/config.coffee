child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
argv = optimist.argv

module.exports =
  getHomeDirectory: ->
    if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME

  getAtomDirectory: ->
    process.env.ATOM_HOME ? path.join(@getHomeDirectory(), '.atom')

  getPackageCacheDirectory: ->
    path.join(@getAtomDirectory(), '.node-gyp', '.atom', '.apm')

  getResourcePath: (callback) ->
    if process.env.ATOM_RESOURCE_PATH
      process.nextTick -> callback(process.env.ATOM_RESOURCE_PATH)
    else
      if process.platform is 'darwin'
        child_process.exec 'mdfind "kMDItemCFBundleIdentifier == \'com.github.atom\'"', (error, stdout='', stderr) ->
          appLocation = stdout.split('\n')[0] ? '/Applications/Atom.app'
          callback("#{appLocation}/Contents/Resources/app")
      else
        process.nextTick -> callback('/usr/local/share/atom/resources/app')

  getReposDirectory: ->
    process.env.ATOM_REPOS_HOME ? path.join(@getHomeDirectory(), 'github')

  getNodeUrl: ->
    process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/atom-shell/dist'

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? 'https://atom.io/api/packages'

  getNodeVersion: ->
    process.env.ATOM_NODE_VERSION ? '0.11.10'

  getNodeArch: ->
    switch process.platform
      when 'darwin' then 'x64'
      when 'win32' then 'ia32'
      else process.arch  # On BSD and Linux we use current machine's arch.

  getUserConfigPath: ->
    path.resolve(__dirname, '..', '.apmrc')

  isWin32: ->
    !!process.platform.match(/^win/)

  isWindows64Bit: ->
    fs.existsSync "C:\\Windows\\SysWow64\\Notepad.exe"

  x86ProgramFilesDirectory: ->
    process.env["ProgramFiles(x86)"] or process.env["ProgramFiles"]

  getMsvsVersion: ->
    return argv['msvs_version']

  getInstalledVisualStudioFlag: ->
    msvsVersion = @getMsvsVersion() || process.env.GYP_MSVS_VERSION
    if msvsVersion
      return msvsVersion

    vs2012Path = path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio 11.0", "Common7", "IDE")
    return '2012' if fs.existsSync(vs2012Path)

    vs2013Path = path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio 12.0", "Common7", "IDE")
    return '2013' if fs.existsSync(vs2013Path)
