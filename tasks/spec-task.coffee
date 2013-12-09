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
    appDir = grunt.config.get('atom.appDir')
    atomPath = path.join(appDir, 'atom.sh')
    apmPath = path.join(appDir, 'node_modules/.bin/apm')

    packageSpecQueue = async.queue (packagePath, callback) ->
      options =
        cmd: apmPath
        args: ['test', '--path', atomPath]
        opts:
          cwd: packagePath
          env: _.extend({}, process.env, ATOM_PATH: rootDir)
      grunt.verbose.writeln "Launching #{path.basename(packagePath)} specs."
      spawn options, (error, results, code) ->

        failedPackages.push path.basename(packagePath) if error
        callback()

    modulesDirectory = path.resolve('node_modules')
    for packageDirectory in fs.readdirSync(modulesDirectory)
      packagePath = path.join(modulesDirectory, packageDirectory)
      continue unless grunt.file.isDir(path.join(packagePath, 'spec'))
      continue unless isAtomPackage(packagePath)
      packageSpecQueue.push(packagePath)

    packageSpecQueue.concurrency = 1
    packageSpecQueue.drain = -> callback(null, failedPackages)

  runCoreSpecs = (callback) ->
    contentsDir = grunt.config.get('atom.contentsDir')
    appPath = path.join(contentsDir, 'MacOS', 'Atom')
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    options =
      cmd: appPath
      args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
    spawn options, (error, results, code) ->
      packageSpecQueue?.concurrency = 2
      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    done = @async()
    startTime = Date.now()

    tasks = [runCoreSpecs]
    tasks.push(runPackageSpecs) if grunt.option('runAllSpecs')

    async.parallel tasks, (error, results) ->
      [coreSpecsFailed, failedPackages] = results
      failedPackages ?= []

      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.verbose.writeln("Total spec time: #{elapsedTime}s")
      failures = failedPackages
      failures.push "atom core" if coreSpecsFailed

      grunt.log.error("[Error]".red + " #{failures.join(', ')} spec(s) failed") if failures.length > 0

      done(!coreSpecsFailed and failedPackages.length == 0)
