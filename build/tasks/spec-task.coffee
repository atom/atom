fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'

async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  packageSpecQueue = null

  runPackageSpecs = (callback) ->
    failedPackages = []
    rootDir = grunt.config.get('atom.shellAppDir')
    contentsDir = grunt.config.get('atom.contentsDir')
    resourcePath = process.cwd()
    if process.platform is 'darwin'
      appPath = path.join(contentsDir, 'MacOS', 'Atom')
    else if process.platform is 'win32'
      appPath = path.join(contentsDir, 'atom.exe')

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
          args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}", "--log-file=ci.log"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)

      grunt.verbose.writeln "Launching #{path.basename(packagePath)} specs."
      spawn options, (error, results, code) ->
        if process.platform is 'win32'
          process.stderr.write(fs.readFileSync(path.join(packagePath, 'ci.log')))
          fs.unlinkSync(path.join(packagePath, 'ci.log'))

        failedPackages.push path.basename(packagePath) if error
        callback()

    modulesDirectory = path.resolve('node_modules')
    for packageDirectory in fs.readdirSync(modulesDirectory)
      packagePath = path.join(modulesDirectory, packageDirectory)
      continue unless grunt.file.isDir(path.join(packagePath, 'spec'))
      continue unless isAtomPackage(packagePath)
      packageSpecQueue.push(packagePath)

    # TODO: Restore concurrency on Windows
    packageSpecQueue.concurrency = 1 unless process.platform is 'win32'

    packageSpecQueue.drain = -> callback(null, failedPackages)

  runCoreSpecs = (callback) ->
    contentsDir = grunt.config.get('atom.contentsDir')
    if process.platform is 'darwin'
      appPath = path.join(contentsDir, 'MacOS', 'Atom')
    else if process.platform is 'win32'
      appPath = path.join(contentsDir, 'atom.exe')
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    if process.platform is 'darwin'
      options =
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
    else if process.platform is 'win32'
      options =
        cmd: process.env.comspec
        args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}", "--log-file=ci.log"]

    spawn options, (error, results, code) ->
      if process.platform is 'win32'
        process.stderr.write(fs.readFileSync('ci.log'))
        fs.unlinkSync('ci.log')
      else
        # TODO: Restore concurrency on Windows
        packageSpecQueue.concurrency = 2

      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    done = @async()
    startTime = Date.now()

    # TODO: This should really be parallel on both platforms, however our
    # fixtures step on each others toes currently.
    if process.platform is 'darwin'
      method = async.parallel
    else if process.platform is 'win32'
      method = async.series

    method [runCoreSpecs, runPackageSpecs], (error, results) ->
      [coreSpecFailed, failedPackages] = results
      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.verbose.writeln("Total spec time: #{elapsedTime}s")
      failures = failedPackages
      failures.push "atom core" if coreSpecFailed

      grunt.log.error("[Error]".red + " #{failures.join(', ')} spec(s) failed") if failures.length > 0
      done(!coreSpecFailed and failedPackages.length == 0)
