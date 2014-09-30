child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
npm = require 'npm'

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
      apmFolder = path.resolve(__dirname, '..', '..', '..')
      appFolder = path.dirname(apmFolder)
      if path.basename(apmFolder) is 'apm' and path.basename(appFolder) is 'app'
        process.nextTick -> callback(appFolder)
      else
        switch process.platform
          when 'darwin'
            child_process.exec 'mdfind "kMDItemCFBundleIdentifier == \'com.github.atom\'"', (error, stdout='', stderr) ->
              appLocation = stdout.split('\n')[0] ? '/Applications/Atom.app'
              callback("#{appLocation}/Contents/Resources/app")
          when 'linux'
            process.nextTick -> callback('/usr/local/share/atom/resources/app')
          when 'win32'
            process.nextTick -> callback(path.join(process.env.ProgramFiles, 'Atom', 'resources', 'app'))

  getReposDirectory: ->
    process.env.ATOM_REPOS_HOME ? path.join(@getHomeDirectory(), 'github')

  getNodeUrl: ->
    process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/atom-shell/dist'

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? "#{@getAtomApiUrl()}/packages"

  getAtomApiUrl: ->
    process.env.ATOM_API_URL ? 'https://atom.io/api'

  getNodeVersion: ->
    process.env.ATOM_NODE_VERSION ? '0.17.0'

  getNodeArch: ->
    switch process.platform
      when 'darwin' then 'x64'
      when 'win32' then 'ia32'
      else process.arch  # On BSD and Linux we use current machine's arch.

  getUserConfigPath: ->
    path.resolve(@getAtomDirectory(), '.apmrc')

  getGlobalConfigPath: ->
    path.resolve(__dirname, '..', '.apmrc')

  isWin32: ->
    process.platform is 'win32'

  isWindows64Bit: ->
    fs.existsSync "C:\\Windows\\SysWow64\\Notepad.exe"

  x86ProgramFilesDirectory: ->
    process.env["ProgramFiles(x86)"] or process.env["ProgramFiles"]

  getInstalledVisualStudioFlag: ->
    return null unless @isWin32()

    # Use the explictly-configured version when set
    return process.env.GYP_MSVS_VERSION if process.env.GYP_MSVS_VERSION

    vs2013Path = path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio 12.0", "Common7", "IDE")
    return '2013' if fs.existsSync(vs2013Path)

    vs2012Path = path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio 11.0", "Common7", "IDE")
    return '2012' if fs.existsSync(vs2012Path)

    vs2010Path = path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio 10.0", "Common7", "IDE")
    return '2010' if fs.existsSync(vs2010Path)

  loadNpm: (callback) ->
    npmOptions =
      userconfig: @getUserConfigPath()
      globalconfig: @getGlobalConfigPath()
    npm.load npmOptions, -> callback(null, npm)

  getSetting: (key, callback) ->
    @loadNpm -> callback(npm.config.get(key))
