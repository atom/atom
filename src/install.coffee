path = require 'path'

async = require 'async'
_ = require 'underscore-plus'
yargs = require 'yargs'
CSON = require 'season'
semver = require 'npm/node_modules/semver'
temp = require 'temp'

config = require './apm'
Command = require './command'
fs = require './fs'
git = require './git'
RebuildModuleCache = require './rebuild-module-cache'
request = require './request'
{isDeprecatedPackage} = require './deprecated-packages'

module.exports =
class Install extends Command
  @commandNames: ['install']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')
    @atomNodeGypPath = require.resolve('npm/node_modules/node-gyp/bin/node-gyp')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm install [<package_name>...]
             apm install <package_name>@<package_version>
             apm install --packages-file my-packages.txt

      Install the given Atom package to ~/.atom/packages/<package_name>.

      If no package name is given then all the dependencies in the package.json
      file are installed to the node_modules folder in the current working
      directory.

      A packages file can be specified that is a newline separated list of
      package names to install with optional versions using the
      `package-name@version` syntax.
    """
    options.alias('c', 'compatible').string('compatible').describe('compatible', 'Only install packages/themes compatible with this Atom version')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('s', 'silent').boolean('silent').describe('silent', 'Set the npm log level to silent')
    options.alias('q', 'quiet').boolean('quiet').describe('quiet', 'Set the npm log level to warn')
    options.boolean('check').describe('check', 'Check that native build tools are installed')
    options.boolean('verbose').default('verbose', false).describe('verbose', 'Show verbose debug information')
    options.string('packages-file').describe('packages-file', 'A text file containing the packages to install')
    options.boolean('production').describe('production', 'Do not install dev dependencies')

  installNode: (callback) =>
    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{@electronVersion}")
    installNodeArgs.push("--dist-url=#{config.getElectronUrl()}")
    installNodeArgs.push("--arch=#{config.getElectronArch()}")
    installNodeArgs.push("--ensure")
    installNodeArgs.push("--verbose") if @verbose

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    fs.makeTreeSync(@atomDirectory)

    # node-gyp doesn't currently have an option for this so just set the
    # environment variable to bypass strict SSL
    # https://github.com/TooTallNate/node-gyp/issues/448
    useStrictSsl = @npm.config.get('strict-ssl') ? true
    env.NODE_TLS_REJECT_UNAUTHORIZED = 0 unless useStrictSsl

    # Pass through configured proxy to node-gyp
    proxy = @npm.config.get('https-proxy') or @npm.config.get('proxy')
    installNodeArgs.push("--proxy=#{proxy}") if proxy

    opts = {env, cwd: @atomDirectory}
    opts.streaming = true if @verbose

    @fork @atomNodeGypPath, installNodeArgs, opts, (code, stderr='', stdout='') ->
      if code is 0
        callback()
      else
        callback("#{stdout}\n#{stderr}")

  updateWindowsEnv: (env) ->
    env.USERPROFILE = env.HOME

    # Make sure node-gyp is always on the PATH
    localModuleBins = path.resolve(__dirname, '..', 'node_modules', '.bin')
    if env.Path
      env.Path += "#{path.delimiter}#{localModuleBins}"
    else
      env.Path = localModuleBins

    git.addGitToEnv(env)

  addNodeBinToEnv: (env) ->
    nodeBinFolder = path.resolve(__dirname, '..', 'bin')
    pathKey = if config.isWin32() then 'Path' else 'PATH'
    if env[pathKey]
      env[pathKey] = "#{nodeBinFolder}#{path.delimiter}#{env[pathKey]}"
    else
      env[pathKey]= nodeBinFolder

  addProxyToEnv: (env) ->
    httpProxy = @npm.config.get('proxy')
    if httpProxy
      env.HTTP_PROXY ?= httpProxy
      env.http_proxy ?= httpProxy

    httpsProxy = @npm.config.get('https-proxy')
    if httpsProxy
      env.HTTPS_PROXY ?= httpsProxy
      env.https_proxy ?= httpsProxy

  installModule: (options, pack, modulePath, callback) ->
    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(modulePath)
    installArgs.push("--target=#{@electronVersion}")
    installArgs.push("--arch=#{config.getElectronArch()}")
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet
    installArgs.push('--production') if options.argv.production

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    @addProxyToEnv(env)
    installOptions = {env}
    installOptions.streaming = true if @verbose

    installGlobally = options.installGlobally ? true
    if installGlobally
      installDirectory = temp.mkdirSync('apm-install-dir-')
      nodeModulesDirectory = path.join(installDirectory, 'node_modules')
      fs.makeTreeSync(nodeModulesDirectory)
      installOptions.cwd = installDirectory

    @fork @atomNpmPath, installArgs, installOptions, (code, stderr='', stdout='') =>
      if code is 0
        if installGlobally
          commands = []
          for child in fs.readdirSync(nodeModulesDirectory)
            source = path.join(nodeModulesDirectory, child)
            destination = path.join(@atomPackagesDirectory, child)
            do (source, destination) ->
              commands.push (callback) -> fs.cp(source, destination, callback)

          commands.push (callback) => @buildModuleCache(pack.name, callback)
          commands.push (callback) => @warmCompileCache(pack.name, callback)

          async.waterfall commands, (error) =>
            if error?
              @logFailure()
            else
              @logSuccess()
            callback(error)
        else
          callback()
      else
        if installGlobally
          fs.removeSync(installDirectory)
          @logFailure()

        error = "#{stdout}\n#{stderr}"
        error = @getGitErrorMessage(pack) if error.indexOf('code ENOGIT') isnt -1
        callback(error)

  getGitErrorMessage: (pack) ->
    message = """
      Failed to install #{pack.name} because Git was not found.

      The #{pack.name} package has module dependencies that cannot be installed without Git.

      You need to install Git and add it to your path environment variable in order to install this package.

    """

    switch process.platform
      when 'win32'
        message += """

          You can install Git by downloading, installing, and launching GitHub for Windows: https://windows.github.com

        """
      when 'linux'
        message += """

          You can install Git from your OS package manager.

        """

    message += """

      Run apm -v after installing Git to see what version has been detected.
    """

    message

  getVisualStudioFlags: ->
    if vsVersion = config.getInstalledVisualStudioFlag()
      "--msvs_version=#{vsVersion}"

  installModules: (options, callback) =>
    process.stdout.write 'Installing modules '

    @forkInstallCommand options, (args...) =>
      @logCommandResults(callback, args...)

  forkInstallCommand: (options, callback) ->
    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push("--target=#{@electronVersion}")
    installArgs.push("--arch=#{config.getElectronArch()}")
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet
    installArgs.push('--production') if options.argv.production

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    @addProxyToEnv(env)
    installOptions = {env}
    installOptions.cwd = options.cwd if options.cwd
    installOptions.streaming = true if @verbose

    @fork(@atomNpmPath, installArgs, installOptions, callback)

  # Request package information from the atom.io API for a given package name.
  #
  # packageName - The string name of the package to request.
  # callback - The function to invoke when the request completes with an error
  #            as the first argument and an object as the second.
  requestPackage: (packageName, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
      retries: 4
    request.get requestSettings, (error, response, body={}) ->
      if error?
        message = "Request for package information failed: #{error.message}"
        message += " (#{error.code})" if error.code
        callback(message)
      else if response.statusCode isnt 200
        message = request.getErrorMessage(response, body)
        callback("Request for package information failed: #{message}")
      else
        if body.releases.latest
          callback(null, body)
        else
          callback("No releases available for #{packageName}")

  # Download a package tarball.
  #
  # packageUrl - The string tarball URL to request
  # installGlobally - `true` if this package is being installed globally.
  # callback - The function to invoke when the request completes with an error
  #            as the first argument and a string path to the downloaded file
  #            as the second.
  downloadPackage: (packageUrl, installGlobally, callback) ->
    requestSettings = url: packageUrl
    request.createReadStream requestSettings, (readStream) =>
      readStream.on 'error', (error) ->
        callback("Unable to download #{packageUrl}: #{error.message}")
      readStream.on 'response', (response) =>
        if response.statusCode is 200
          filePath = path.join(temp.mkdirSync(), 'package.tgz')
          writeStream = fs.createWriteStream(filePath)
          readStream.pipe(writeStream)
          writeStream.on 'error', (error) ->
            callback("Unable to download #{packageUrl}: #{error.message}")
          writeStream.on 'close', -> callback(null, filePath)
        else
          chunks = []
          response.on 'data', (chunk) -> chunks.push(chunk)
          response.on 'end', =>
            try
              error = JSON.parse(Buffer.concat(chunks))
              message = error.message ? error.error ? error
              @logFailure() if installGlobally
              callback("Unable to download #{packageUrl}: #{response.headers.status ? response.statusCode} #{message}")
            catch parseError
              @logFailure() if installGlobally
              callback("Unable to download #{packageUrl}: #{response.headers.status ? response.statusCode}")

  # Get the path to the package from the local cache.
  #
  #  packageName - The string name of the package.
  #  packageVersion - The string version of the package.
  #  callback - The function to call with error and cachePath arguments.
  #
  # Returns a path to the cached tarball or undefined when not in the cache.
  getPackageCachePath: (packageName, packageVersion, callback) ->
    cacheDir = config.getCacheDirectory()
    cachePath = path.join(cacheDir, packageName, packageVersion, 'package.tgz')
    if fs.isFileSync(cachePath)
      tempPath = path.join(temp.mkdirSync(), path.basename(cachePath))
      fs.cp cachePath, tempPath, (error) ->
        if error?
          callback(error)
        else
          callback(null, tempPath)
    else
      process.nextTick ->
        callback(new Error("#{packageName}@#{packageVersion} is not in the cache"))

  # Is the package at the specified version already installed?
  #
  #  * packageName: The string name of the package.
  #  * packageVersion: The string version of the package.
  isPackageInstalled: (packageName, packageVersion) ->
    try
      {version} = CSON.readFileSync(CSON.resolve(path.join('node_modules', packageName, 'package'))) ? {}
      packageVersion is version
    catch error
      false

  # Install the package with the given name and optional version
  #
  # metadata - The package metadata object with at least a name key. A version
  #            key is also supported. The version defaults to the latest if
  #            unspecified.
  # options - The installation options object.
  # callback - The function to invoke when installation completes with an
  #            error as the first argument.
  installPackage: (metadata, options, callback) ->
    packageName = metadata.name
    packageVersion = metadata.version

    installGlobally = options.installGlobally ? true
    unless installGlobally
      if packageVersion and @isPackageInstalled(packageName, packageVersion)
        callback()
        return

    label = packageName
    label += "@#{packageVersion}" if packageVersion
    process.stdout.write "Installing #{label} "
    if installGlobally
      process.stdout.write "to #{@atomPackagesDirectory} "

    @requestPackage packageName, (error, pack) =>
      if error?
        @logFailure()
        callback(error)
      else
        packageVersion ?= @getLatestCompatibleVersion(pack)
        unless packageVersion
          @logFailure()
          callback("No available version compatible with the installed Atom version: #{@installedAtomVersion}")

        {tarball} = pack.versions[packageVersion]?.dist ? {}
        unless tarball
          @logFailure()
          callback("Package version: #{packageVersion} not found")
          return

        commands = []
        commands.push (callback) =>
          @getPackageCachePath packageName, packageVersion, (error, packagePath) =>
            if packagePath
              callback(null, packagePath)
            else
              @downloadPackage(tarball, installGlobally, callback)
        installNode = options.installNode ? true
        if installNode
          commands.push (packagePath, callback) =>
            @installNode (error) -> callback(error, packagePath)
        commands.push (packagePath, callback) =>
          @installModule(options, pack, packagePath, callback)

        async.waterfall commands, (error) =>
          unless installGlobally
            if error?
              @logFailure()
            else
              @logSuccess()
          callback(error)

  # Install all the package dependencies found in the package.json file.
  #
  # options - The installation options
  # callback - The callback function to invoke when done with an error as the
  #            first argument.
  installPackageDependencies: (options, callback) ->
    options = _.extend({}, options, installGlobally: false, installNode: false)
    commands = []
    for name, version of @getPackageDependencies()
      do (name, version) =>
        commands.push (callback) =>
          @installPackage({name, version}, options, callback)

    async.waterfall(commands, callback)

  installDependencies: (options, callback) ->
    options.installGlobally = false
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModules(options, callback)
    commands.push (callback) => @installPackageDependencies(options, callback)

    async.waterfall commands, callback

  # Get all package dependency names and versions from the package.json file.
  getPackageDependencies: ->
    try
      metadata = fs.readFileSync('package.json', 'utf8')
      {packageDependencies} = JSON.parse(metadata) ? {}
      packageDependencies ? {}
    catch error
      {}

  createAtomDirectories: ->
    fs.makeTreeSync(@atomDirectory)
    fs.makeTreeSync(@atomPackagesDirectory)
    fs.makeTreeSync(@atomNodeDirectory)

  # Compile a sample native module to see if a useable native build toolchain
  # is instlalled and successfully detected. This will include both Python
  # and a compiler.
  checkNativeBuildTools: (callback) ->
    process.stdout.write 'Checking for native build tools '
    @installNode (error) =>
      if error?
        @logFailure()
        return callback(error)

      buildArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'build']
      buildArgs.push(path.resolve(__dirname, '..', 'native-module'))
      buildArgs.push("--target=#{@electronVersion}")
      buildArgs.push("--arch=#{config.getElectronArch()}")

      if vsArgs = @getVisualStudioFlags()
        buildArgs.push(vsArgs)

      env = _.extend({}, process.env, HOME: @atomNodeDirectory)
      @updateWindowsEnv(env) if config.isWin32()
      @addNodeBinToEnv(env)
      @addProxyToEnv(env)
      buildOptions = {env}
      buildOptions.streaming = true if @verbose

      fs.removeSync(path.resolve(__dirname, '..', 'native-module', 'build'))

      @fork @atomNpmPath, buildArgs, buildOptions, (args...) =>
        @logCommandResults(callback, args...)

  packageNamesFromPath: (filePath) ->
    filePath = path.resolve(filePath)

    unless fs.isFileSync(filePath)
      throw new Error("File '#{filePath}' does not exist")

    packages = fs.readFileSync(filePath, 'utf8')
    @sanitizePackageNames(packages.split(/\s/))

  buildModuleCache: (packageName, callback) ->
    packageDirectory = path.join(@atomPackagesDirectory, packageName)
    rebuildCacheCommand = new RebuildModuleCache()
    rebuildCacheCommand.rebuild packageDirectory, ->
      # Ignore cache errors and just finish the install
      callback()

  warmCompileCache: (packageName, callback) ->
    packageDirectory = path.join(@atomPackagesDirectory, packageName)

    @getResourcePath (resourcePath) =>
      try
        CompileCache = require(path.join(resourcePath, 'src', 'compile-cache'))

        onDirectory = (directoryPath) ->
          path.basename(directoryPath) isnt 'node_modules'

        onFile = (filePath) =>
          try
            CompileCache.addPathToCache(filePath, @atomDirectory)

        fs.traverseTreeSync(packageDirectory, onFile, onDirectory)
      callback(null)

  isBundledPackage: (packageName, callback) ->
    @getResourcePath (resourcePath) ->
      try
        atomMetadata = JSON.parse(fs.readFileSync(path.join(resourcePath, 'package.json')))
      catch error
        return callback(false)

      callback(atomMetadata?.packageDependencies?.hasOwnProperty(packageName))

  getLatestCompatibleVersion: (pack) ->
    unless @installedAtomVersion
      if isDeprecatedPackage(pack.name, pack.releases.latest)
        return null
      else
        return pack.releases.latest

    latestVersion = null
    for version, metadata of pack.versions ? {}
      continue unless semver.valid(version)
      continue unless metadata
      continue if isDeprecatedPackage(pack.name, version)

      engine = metadata.engines?.atom ? '*'
      continue unless semver.validRange(engine)
      continue unless semver.satisfies(@installedAtomVersion, engine)

      latestVersion ?= version
      latestVersion = version if semver.gt(version, latestVersion)

    latestVersion

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packagesFilePath = options.argv['packages-file']

    @createAtomDirectories()

    if options.argv.check
      config.loadNpm (error, @npm) =>
        @loadInstalledAtomMetadata =>
          @checkNativeBuildTools(callback)
      return

    @verbose = options.argv.verbose
    if @verbose
      request.debug(true)
      process.env.NODE_DEBUG = 'request'

    installPackage = (name, callback) =>
      if name is '.'
        @installDependencies(options, callback)
      else
        atIndex = name.indexOf('@')
        if atIndex > 0
          version = name.substring(atIndex + 1)
          name = name.substring(0, atIndex)

        @isBundledPackage name, (isBundledPackage) =>
          if isBundledPackage
            console.error """
              The #{name} package is bundled with Atom and should not be explicitly installed.
              You can run `apm uninstall #{name}` to uninstall it and then the version bundled
              with Atom will be used.
            """.yellow
          @installPackage({name, version}, options, callback)

    if packagesFilePath
      try
        packageNames = @packageNamesFromPath(packagesFilePath)
      catch error
        return callback(error)
    else
      packageNames = @packageNamesFromArgv(options.argv)
      packageNames.push('.') if packageNames.length is 0

    commands = []
    commands.push (callback) => config.loadNpm (error, @npm) => callback()
    commands.push (callback) => @loadInstalledAtomMetadata(callback)
    packageNames.forEach (packageName) ->
      commands.push (callback) -> installPackage(packageName, callback)
    async.waterfall(commands, callback)
