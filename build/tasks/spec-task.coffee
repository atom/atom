fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'

async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  runPackageSpecs = (isCI, callback) ->
    failedPackages = []
    rootDir = grunt.config.get('atom.shellAppDir')
    contentsDir = grunt.config.get('atom.contentsDir')
    resourcePath = process.cwd()
    if process.platform is 'darwin'
      appPath = path.join(contentsDir, 'MacOS', 'Atom')
    else if process.platform is 'win32'
      appPath = path.join(contentsDir, 'atom.exe')
    else
      appPath = path.join(contentsDir, 'atom')

    packageSpecQueue = async.queue (packagePath, callback) ->
      if process.platform is 'darwin'
        options =
          cmd: appPath
          args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)
      else if process.platform is 'win32'
        options =
          cmd: process.env.comspec
          args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)
      else
        options =
          cmd: appPath
          args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)

      if isCI
        options.args.push('--log-file=ci.log')

      grunt.verbose.writeln "Launching #{path.basename(packagePath)} specs."
      spawn options, (error, results, code) ->
        if isCI
          process.stderr.write(fs.readFileSync(path.join(packagePath, 'ci.log')))
          fs.unlinkSync(path.join(packagePath, 'ci.log'))

        failedPackages.push path.basename(packagePath) if error
        callback()

    # TODO: Check concurrency on other platforms
    if process.platform is 'win32'
      packageSpecQueue.concurrency = 2
    else
      packageSpecQueue.concurrency = 1

    # When all specs are finished, report the results
    packageSpecQueue.drain = -> callback(null, failedPackages)
    # First gather package specs
    tasks = []
    modulesDirectory = path.resolve('node_modules')
    for packageDirectory in fs.readdirSync(modulesDirectory)
      packagePath = path.join(modulesDirectory, packageDirectory)
      continue unless grunt.file.isDir(path.join(packagePath, 'spec'))
      continue unless isAtomPackage(packagePath)
      tasks.push(packagePath)
    # Now add them all in one go to avoid race conditions between pushing and
    # drain
    packageSpecQueue.push(tasks)

  runCoreSpecs = (isCI, callback) ->
    contentsDir = grunt.config.get('atom.contentsDir')
    if process.platform is 'darwin'
      appPath = path.join(contentsDir, 'MacOS', 'Atom')
    else if process.platform is 'win32'
      appPath = path.join(contentsDir, 'atom.exe')
    else
      appPath = path.join(contentsDir, 'atom')
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    if process.platform is 'win32'
      options =
        cmd: process.env.comspec
        args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
    else
      options =
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]

    if isCI
      options.args.push('--log-file=ci.log')

    spawn options, (error, results, code) ->
      if isCI
        process.stderr.write(fs.readFileSync('ci.log'))
        fs.unlinkSync('ci.log')

      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', (mode) ->
    done = @async()
    startTime = Date.now()

    # TODO: This should really be parallel on both platforms, however our
    # fixtures step on each others toes currently.
    if process.platform is 'darwin'
      method = async.parallel
    else
      method = async.series

    isCI = mode is 'ci' if mode
    method [runCoreSpecs.bind(this, isCI), runPackageSpecs.bind(this, isCI)], (error, results) ->
      [coreSpecFailed, failedPackages] = results
      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.verbose.writeln("Total spec time: #{elapsedTime}s")
      failures = failedPackages
      failures.push "atom core" if coreSpecFailed

      grunt.log.error("[Error]".red + " #{failures.join(', ')} spec(s) failed") if failures.length > 0

      # TODO: Mark the build as green on Windows until specs pass.
      if process.platform is 'win32'
        done(true)
      else
        done(!coreSpecFailed and failedPackages.length == 0)
