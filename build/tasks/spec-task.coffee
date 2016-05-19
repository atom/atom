fs = require 'fs'
path = require 'path'
temp = require('temp').track()

_ = require 'underscore-plus'
async = require 'async'

# TODO: This should really be parallel on every platform, however:
# - On Windows, our fixtures step on each others toes.
if process.platform is 'win32'
  concurrency = 1
else
  concurrency = 2

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  packageSpecQueue = null

  getAppPath = ->
    contentsDir = grunt.config.get('atom.contentsDir')
    switch process.platform
      when 'darwin'
        path.join(contentsDir, 'MacOS', 'Atom')
      when 'linux'
        path.join(contentsDir, 'atom')
      when 'win32'
        path.join(contentsDir, 'atom.exe')

  runPackageSpecs = (callback) ->
    failedPackages = []
    rootDir = grunt.config.get('atom.shellAppDir')
    resourcePath = process.cwd()
    appPath = getAppPath()

    # Ensure application is executable on Linux
    fs.chmodSync(appPath, '755') if process.platform is 'linux'

    packageSpecQueue = async.queue (packagePath, callback) ->
      if process.platform in ['darwin', 'linux']
        options =
          cmd: appPath
          args: ['--test', "--resource-path=#{resourcePath}", path.join(packagePath, 'spec')]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ELECTRON_ENABLE_LOGGING: true, ATOM_PATH: rootDir)
      else if process.platform is 'win32'
        options =
          cmd: process.env.comspec
          args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--log-file=ci.log", path.join(packagePath, 'spec')]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ELECTRON_ENABLE_LOGGING: true, ATOM_PATH: rootDir)

      grunt.log.ok "Launching #{path.basename(packagePath)} specs."
      spawn options, (error, results, code) ->
        if process.platform is 'win32'
          if error
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

    packageSpecQueue.concurrency = Math.max(1, concurrency - 1)
    packageSpecQueue.drain = -> callback(null, failedPackages)

  runCoreSpecs = (callback) ->
    appPath = getAppPath()
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    if process.platform in ['darwin', 'linux']
      options =
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", coreSpecsPath, "--user-data-dir=#{temp.mkdirSync('atom-user-data-dir')}"]
        opts:
          env: _.extend({}, process.env, {ELECTRON_ENABLE_LOGGING: true, ATOM_INTEGRATION_TESTS_ENABLED: true})
          stdio: 'inherit'

    else if process.platform is 'win32'
      options =
        cmd: process.env.comspec
        args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", '--log-file=ci.log', coreSpecsPath]
        opts:
          env: _.extend({}, process.env, {ELECTRON_ENABLE_LOGGING: true, ATOM_INTEGRATION_TESTS_ENABLED: true})
          stdio: 'inherit'

    grunt.log.ok "Launching core specs."
    spawn options, (error, results, code) ->
      if process.platform is 'win32'
        process.stderr.write(fs.readFileSync('ci.log')) if error
        fs.unlinkSync('ci.log')
      else
        # TODO: Restore concurrency on Windows
        packageSpecQueue?.concurrency = concurrency

      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    done = @async()
    startTime = Date.now()
    method =
      if concurrency is 1
        async.series
      else
        async.parallel

    specs =
      if process.env.ATOM_SPECS_TASK is 'packages'
        [runPackageSpecs]
      else if process.env.ATOM_SPECS_TASK is 'core'
        [runCoreSpecs]
      else
        [runCoreSpecs, runPackageSpecs]

    method specs, (error, results) ->
      failedPackages = []
      coreSpecFailed = null

      if process.env.ATOM_SPECS_TASK is 'packages'
        [failedPackages] = results
      else if process.env.ATOM_SPECS_TASK is 'core'
        [coreSpecFailed] = results
      else
        [coreSpecFailed, failedPackages] = results

      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.log.ok("Total spec time: #{elapsedTime}s using #{concurrency} cores")
      failures = failedPackages
      failures.push "atom core" if coreSpecFailed

      grunt.log.error("[Error]".red + " #{failures.join(', ')} spec(s) failed") if failures.length > 0

      if process.platform is 'win32' and process.env.JANKY_SHA1
        done()
      else
        done(not coreSpecFailed and failedPackages.length is 0)
