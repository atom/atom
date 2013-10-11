path = require 'path'

async = require 'async'
_ = require 'underscore'
optimist = require 'optimist'
temp = require 'temp'
require 'colors'

config = require './config'
Command = require './command'
fs = require './fs'

module.exports =
class Installer extends Command
  @commandNames: ['install']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')
    @atomNodeGypPath = require.resolve('node-gyp/bin/node-gyp')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm install [<package_name>]

      Install the given Atom package to ~/.atom/packages/<package_name>.

      If no package name is given then all the dependencies in the package.json
      file are installed into the node_modules folder for the current working
      directory.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').describe('dev', 'Install dev dependencies of atom packages being installed')
    options.boolean('silent').describe('silent', 'Minimize output')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  installNode: (callback) =>
    process.stdout.write "Installing node@#{config.getNodeVersion()} "

    installNodeArgs = ['install']
    installNodeArgs.push("--target=#{config.getNodeVersion()}")
    installNodeArgs.push("--dist-url=#{config.getNodeUrl()}")
    installNodeArgs.push('--arch=ia32')

    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    fs.mkdir(@atomDirectory)
    @fork @atomNodeGypPath, installNodeArgs, {env, cwd: @atomDirectory}, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  installModule: (options, modulePath, callback) ->
    process.stdout.write "Installing #{modulePath} to #{@atomPackagesDirectory} "

    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(modulePath)
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--msvs_version=2012') if config.isWin32()
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()

    installDirectory = temp.mkdirSync('apm-install-dir-')
    nodeModulesDirectory = path.join(installDirectory, 'node_modules')
    fs.mkdir(nodeModulesDirectory)
    @fork @atomNpmPath, installArgs, {env, cwd: installDirectory}, (code, stderr='', stdout='') =>
      if code is 0
        for child in fs.readdirSync(nodeModulesDirectory)
          fs.cp(path.join(nodeModulesDirectory, child), path.join(@atomPackagesDirectory, child), forceDelete: true)
        fs.rm(installDirectory)
        process.stdout.write '\u2713\n'.green
        callback()
      else
        fs.rm(installDirectory)
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  installModules: (options, callback) =>
    process.stdout.write 'Installing modules '

    @forkInstallCommand options, (code, stderr='', stdout='') =>
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback(stdout.red + stderr.red)

  forkInstallCommand: (options, callback) ->
    installArgs = ['--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push("--target=#{config.getNodeVersion()}")
    installArgs.push('--arch=ia32')
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--msvs_version=2012') if config.isWin32()
    env = _.extend({}, process.env, HOME: @atomNodeDirectory)
    env.USERPROFILE = env.HOME if config.isWin32()
    installOptions = {env}
    installOptions.cwd = options.cwd if options.cwd

    @fork(@atomNpmPath, installArgs, installOptions, callback)

  installPackage: (options, modulePath, callback) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModule(options, modulePath, callback)

    async.waterfall(commands, callback)

  installDependencies: (options, callback) ->
    commands = []
    commands.push(@installNode)
    commands.push (callback) => @installModules(options, callback)
    if options.argv.dev
      commands.push (callback) => @installDevDependencies(options, callback)

    async.waterfall commands, callback

  isAtomPackageWithDevDependencies: (packagePath) ->
    try
      metadata = fs.readFileSync(path.join(packagePath, 'package.json'), 'utf8')
      {engines, devDependencies} = JSON.parse(metadata) ? {}
      engines?.atom? and devDependencies and Object.keys(devDependencies).length > 0
    catch error
      false

  installDevDependencies: (options, callback) ->
    commands = []
    modulesDirectory = path.resolve('node_modules')
    for child in fs.readdirSync(modulesDirectory)
      packagePath = path.join(modulesDirectory, child)
      continue unless @isAtomPackageWithDevDependencies(packagePath)
      do (child, packagePath) =>
        commands.push (callback) =>
          options.cwd = packagePath
          @forkInstallCommand options, (code, stderr='', stdout='') =>
            if code is 0
              callback()
            else
              callback(stdout.red + stderr.red)

    async.waterfall commands, callback

  installTextMateBundle: (options, bundlePath, callback) ->
    gitArguments = ['clone']
    gitArguments.push(bundlePath)
    gitArguments.push(path.join(@atomPackagesDirectory, path.basename(bundlePath, '.git')))
    @spawn 'git', gitArguments, (code) ->
      if code is 0
        callback()
      else
        callback("Installing bundle failed with code: #{code}")

  isTextMateBundlePath: (bundlePath) ->
    path.extname(path.basename(bundlePath, '.git')) is '.tmbundle'

  createAtomDirectories: ->
    fs.mkdir(@atomDirectory)
    fs.mkdir(@atomPackagesDirectory)
    fs.mkdir(@atomNodeDirectory)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @createAtomDirectories()
    modulePath = options.argv._[0] ? '.'
    if modulePath is '.'
      @installDependencies(options, callback)
    else if @isTextMateBundlePath(modulePath)
      @installTextMateBundle(options, modulePath, callback)
    else
      @installPackage(options, modulePath, callback)
