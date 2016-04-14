fs = require 'fs'
path = require 'path'
temp = require('temp').track()

_ = require 'underscore-plus'
async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  packageSpecQueue = null

  getAppPath = ->
    contentsDir = grunt.config.get('atom.contentsDir')
    path.join(contentsDir, 'MacOS', 'Atom')

  runPackageSpecs = (callback) ->
    failedPackages = []
    rootDir = grunt.config.get('atom.shellAppDir')
    resourcePath = process.cwd()
    appPath = getAppPath()

    packageSpecQueue = async.queue (packagePath, callback) ->
      options =
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", path.join(packagePath, 'spec')]
        opts:
          cwd: packagePath
          env: _.extend({}, process.env, ELECTRON_ENABLE_LOGGING: true, ATOM_PATH: rootDir)

      grunt.log.ok "Launching #{path.basename(packagePath)} specs."
      spawn options, (error) ->
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
    appPath = getAppPath()
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    options =
      cmd: appPath
      args: ['--test', "--resource-path=#{resourcePath}", coreSpecsPath, "--user-data-dir=#{temp.mkdirSync('atom-user-data-dir')}"]
      opts:
        env: _.extend({}, process.env, {ATOM_INTEGRATION_TESTS_ENABLED: true, ELECTRON_ENABLE_LOGGING: true})
        stdio: 'inherit'

    grunt.log.ok "Launching core specs."
    spawn options, (error, results) ->
      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    done = @async()
    startTime = Date.now()

    specs =
      if process.env.ATOM_SPECS_TASK is 'packages'
        [runPackageSpecs]
      else if process.env.ATOM_SPECS_TASK is 'core'
        [runCoreSpecs]
      else
        [runCoreSpecs, runPackageSpecs]

    async.series specs, (error, results) ->
      failedPackages = []
      coreSpecFailed = null

      if process.env.ATOM_SPECS_TASK is 'packages'
        [failedPackages] = results
      else if process.env.ATOM_SPECS_TASK is 'core'
        [coreSpecFailed] = results
      else
        [coreSpecFailed, failedPackages] = results

      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.log.ok("Total spec time: #{elapsedTime}s")
      failures = failedPackages
      failures.push "atom core" if coreSpecFailed

      grunt.log.error("[Error]".red + " #{failures.join(', ')} spec(s) failed") if failures.length > 0

      done(not coreSpecFailed and failedPackages.length is 0)
