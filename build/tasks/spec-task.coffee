fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
async = require 'async'

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

    packageSpecQueue.concurrency = 1
    packageSpecQueue.drain = -> callback(null, failedPackages)

  runCoreSpecs = (callback) ->
    appPath = getAppPath()
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    if process.platform in ['darwin', 'linux']
      options =
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
    else if process.platform is 'win32'
      options =
        cmd: process.env.comspec
        args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}", "--log-file=ci.log"]

    spawn options, (error, results, code) ->
      if process.platform is 'win32'
        process.stderr.write(fs.readFileSync('ci.log')) if error
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
    if process.platform in ['darwin', 'linux']
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

      if process.platform is 'win32' and process.env.JANKY_SHA1
        # Package specs are still flaky on Windows CI
        done(!coreSpecFailed)
      else
        done(!coreSpecFailed and failedPackages.length == 0)
