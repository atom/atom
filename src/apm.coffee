child_process = require 'child_process'
fs = require './fs'
path = require 'path'
npm = require 'npm'
semver = require 'semver'

module.exports =
  getHomeDirectory: ->
    if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME

  getAtomDirectory: ->
    process.env.ATOM_HOME ? path.join(@getHomeDirectory(), '.atom')

  getCacheDirectory: ->
    path.join(@getAtomDirectory(), '.apm')

  getResourcePath: (callback) ->
    if process.env.ATOM_RESOURCE_PATH
      return process.nextTick -> callback(process.env.ATOM_RESOURCE_PATH)

    apmFolder = path.resolve(__dirname, '..')
    appFolder = path.dirname(apmFolder)
    if path.basename(apmFolder) is 'apm' and path.basename(appFolder) is 'app'
      asarPath = "#{appFolder}.asar"
      if fs.existsSync(asarPath)
        return process.nextTick -> callback(asarPath)

    apmFolder = path.resolve(__dirname, '..', '..', '..')
    appFolder = path.dirname(apmFolder)
    if path.basename(apmFolder) is 'apm' and path.basename(appFolder) is 'app'
      asarPath = "#{appFolder}.asar"
      if fs.existsSync(asarPath)
        return process.nextTick -> callback(asarPath)

    switch process.platform
      when 'darwin'
        child_process.exec 'mdfind "kMDItemCFBundleIdentifier == \'com.github.atom\'"', (error, stdout='', stderr) ->
          [appLocation] = stdout.split('\n') unless error
          appLocation = '/Applications/Atom.app' unless appLocation
          callback("#{appLocation}/Contents/Resources/app.asar")
      when 'linux'
        appLocation = '/usr/local/share/atom/resources/app.asar'
        unless fs.existsSync(appLocation)
          appLocation = '/usr/share/atom/resources/app.asar'
        process.nextTick -> callback(appLocation)
      when 'win32'
        process.nextTick ->
          programFilesPath = path.join(process.env.ProgramFiles, 'Atom', 'resources', 'app.asar')
          callback(programFilesPath)

  getReposDirectory: ->
    process.env.ATOM_REPOS_HOME ? path.join(@getHomeDirectory(), 'github')

  getElectronUrl: ->
    process.env.ATOM_ELECTRON_URL ? 'https://atom.io/download/atom-shell'

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? "#{@getAtomApiUrl()}/packages"

  getAtomApiUrl: ->
    process.env.ATOM_API_URL ? 'https://atom.io/api'

  getElectronArch: ->
    switch process.platform
      when 'darwin' then 'x64'
      when 'win32' then 'ia32'
      else process.arch  # On BSD and Linux we use current machine's arch.

  getUserConfigPath: ->
    path.resolve(@getAtomDirectory(), '.apmrc')

  getGlobalConfigPath: ->
    path.resolve(@getAtomDirectory(), '.apm', '.apmrc')

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

    return '2015' if @visualStudioIsInstalled("14.0")
    return '2013' if @visualStudioIsInstalled("12.0")
    return '2012' if @visualStudioIsInstalled("11.0")
    return '2010' if @visualStudioIsInstalled("10.0")

  visualStudioIsInstalled: (version) ->
    fs.existsSync(path.join(@x86ProgramFilesDirectory(), "Microsoft Visual Studio #{version}", "Common7", "IDE"))

  loadNpm: (callback) ->
    npmOptions =
      userconfig: @getUserConfigPath()
      globalconfig: @getGlobalConfigPath()
    npm.load npmOptions, -> callback(null, npm)

  getSetting: (key, callback) ->
    @loadNpm -> callback(npm.config.get(key))

  setupApmRcFile: ->
    try
      fs.writeFileSync @getGlobalConfigPath(), """
        ; This file is auto-generated and should not be edited since any
        ; modifications will be lost the next time any apm command is run.
        ;
        ; You should instead edit your .apmrc config located in ~/.atom/.apmrc
        cache = #{@getCacheDirectory()}
        progress = false
      """
