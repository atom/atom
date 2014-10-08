path = require 'path'

async = require 'async'
_ = require 'underscore-plus'
optimist = require 'optimist'
CSON = require 'season'
semver = require 'semver'
temp = require 'temp'

config = require './config'
Command = require './command'
fs = require './fs'
request = require './request'

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
    options = optimist(argv)
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
    options.alias('c', 'compatible').string('compatible').describe('compatible', 'Only list packages/themes compatible with this Atom version')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('s', 'silent').boolean('silent').describe('silent', 'Set the npm log level to silent')
    options.alias('q', 'quiet').boolean('quiet').describe('quiet', 'Set the npm log level to warn')
    options.boolean('check').describe('check', 'Check that native build tools are installed')
    options.string('packages-file').describe('packages-file', 'A text file containing the packages to install')

  installNode: (callback) =>
    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{config.getNodeVersion()}")
    installNodeArgs.push("--dist-url=#{config.getNodeUrl()}")
    installNodeArgs.push("--arch=#{config.getNodeArch()}")

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    fs.makeTreeSync(@atomDirectory)

    config.loadNpm (error, npm) =>
      # node-gyp doesn't currently have an option for this so just set the
      # environment variable to bypass strict SSL
      # https://github.com/TooTallNate/node-gyp/issues/448
      useStrictSsl = npm.config.get('strict-ssl') ? true
      env.NODE_TLS_REJECT_UNAUTHORIZED = 0 unless useStrictSsl

      # Pass through configured proxy to node-gyp
      proxy = npm.config.get('https-proxy') or npm.config.get('proxy')
      installNodeArgs.push("--proxy=#{proxy}") if proxy

      @fork @atomNodeGypPath, installNodeArgs, {env, cwd: @atomDirectory}, (code, stderr='', stdout='') ->
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

  addNodeBinToEnv: (env) ->
    nodeBinFolder = path.resolve(__dirname, '..', 'bin')
    pathKey = if config.isWin32() then 'Path' else 'PATH'
    if env[pathKey]
      env[pathKey] = "#{nodeBinFolder}#{path.delimiter}#{env[pathKey]}"
    else
      env[pathKey]= nodeBinFolder

  installModule: (options, pack, modulePath, callback) ->
    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(modulePath)
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push("--arch=#{config.getNodeArch()}")
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    installOptions = {env}

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

        callback("#{stdout}\n#{stderr}")

  getVisualStudioFlags: ->
    if vsVersion = config.getInstalledVisualStudioFlag()
      "--msvs_version=#{vsVersion}"

  installModules: (options, callback) =>
    process.stdout.write 'Installing modules '

    @forkInstallCommand options, (args...) =>
      @logCommandResults(callback, args...)

  forkInstallCommand: (options, callback) ->
    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push("--arch=#{config.getNodeArch()}")
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    installOptions = {env}
    installOptions.cwd = options.cwd if options.cwd

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
    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback("Request for package information failed: #{error.message}")
      else if response.statusCode isnt 200
        message = body.message ? body.error ? body
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
          writeStream.on 'error', (errror) ->
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
  #
  # Returns a path to the cached tarball or undefined when not in the cache.
  getPackageCachePath: (packageName, packageVersion) ->
    cacheDir = config.getPackageCacheDirectory()
    cachePath = path.join(cacheDir, packageName, packageVersion, 'package.tgz')
    return cachePath if fs.isFileSync(cachePath)

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
          if packagePath = @getPackageCachePath(packageName, packageVersion)
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
      buildArgs.push("--target=#{config.getNodeVersion()}")
      buildArgs.push("--arch=#{config.getNodeArch()}")

      if vsArgs = @getVisualStudioFlags()
        buildArgs.push(vsArgs)

      env = _.extend({}, process.env, HOME: @atomNodeDirectory)
      @updateWindowsEnv(env) if config.isWin32()
      @addNodeBinToEnv(env)
      buildOptions = {env}

      fs.removeSync(path.resolve(__dirname, '..', 'native-module', 'build'))

      @fork @atomNpmPath, buildArgs, buildOptions, (args...) =>
        @logCommandResults(callback, args...)

  packageNamesFromPath: (filePath) ->
    filePath = path.resolve(filePath)

    unless fs.isFileSync(filePath)
      throw new Error("File '#{filePath}' does not exist")

    packages = fs.readFileSync(filePath, 'utf8')
    @sanitizePackageNames(packages.split(/\s/))

  getResourcePath: (callback) ->
    if @resourcePath
      process.nextTick => callback(@resourcePath)
    else
      config.getResourcePath (@resourcePath) => callback(@resourcePath)

  buildModuleCache: (packageName, callback) ->
    packageDirectory = path.join(@atomPackagesDirectory, packageName)

    config.getResourcePath (resourcePath) ->
      try
        ModuleCache = require(path.join(resourcePath, 'src', 'module-cache'))
        ModuleCache.create(packageDirectory)
      callback()

  isBundledPackage: (packageName, callback) ->
    @getResourcePath (resourcePath) ->
      try
        atomMetadata = JSON.parse(fs.readFileSync(path.join(resourcePath, 'package.json')))
      catch error
        return callback(false)

      callback(atomMetadata?.packageDependencies?.hasOwnProperty(packageName))

  getLatestCompatibleVersion: (pack) ->
    return pack.releases.latest unless @installedAtomVersion

    latestVersion = null
    for version, metadata of pack.versions ? {}
      continue unless semver.valid(version)
      continue unless metadata

      engine = metadata.engines?.atom ? '*'
      continue unless semver.validRange(engine)
      continue unless semver.satisfies(@installedAtomVersion, engine)

      latestVersion ?= version
      latestVersion = version if semver.gt(version, latestVersion)

    latestVersion

  loadInstalledAtomVersion: (callback) ->
    @getResourcePath (resourcePath) =>
      try
        {version} = require(path.join(resourcePath, 'package.json')) ? {}
        @installedAtomVersion = version if semver.valid(version)
      callback()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packagesFilePath = options.argv['packages-file']

    @createAtomDirectories()

    return @checkNativeBuildTools(callback) if options.argv.check

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
    commands.push (callback) => @loadInstalledAtomVersion(callback)
    packageNames.forEach (packageName) ->
      commands.push (callback) -> installPackage(packageName, callback)
    async.waterfall(commands, callback)
