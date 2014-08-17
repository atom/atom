fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'

async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn, withPlatform} = require('./task-helpers')(grunt)

  packageSpecQueue = null

  runPackageSpecs = (callback) ->
    failedPackages = []
    rootDir = grunt.config.get('atom.shellAppDir')
    contentsDir = grunt.config.get('atom.contentsDir')
    resourcePath = process.cwd()
    appPath = withPlatform
      darwin: -> path.join(contentsDir, 'MacOS', 'Atom')
      linux: -> path.join(contentsDir, 'atom')
      win32: -> path.join(contentsDir, 'atom.exe')

    packageSpecQueue = async.queue (packagePath, callback) ->
      options = withPlatform
        darwin: ->
          cmd: appPath
          args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)
        linux: ->
          cmd: appPath
          args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{path.join(packagePath, 'spec')}"]
          opts:
            cwd: packagePath
            env: _.extend({}, process.env, ATOM_PATH: rootDir)
        win32: ->
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
    contentsDir = grunt.config.get('atom.contentsDir')

    appPath = withPlatform
      darwin: -> path.join(contentsDir, 'MacOS', 'Atom')
      win32: -> path.join(contentsDir, 'atom.exe')
      linux: -> path.join(contentsDir, 'atom')

    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    options = withPlatform
      darwin: ->
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
      linux: ->
        cmd: appPath
        args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
      win32: ->
        cmd: process.env.comspec
        args: ['/c', appPath, '--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}", "--log-file=ci.log"]

    spawn options, (error, results, code) ->
      withPlatform
        darwin: ->
          # TODO: Restore concurrency on Windows
          packageSpecQueue.concurrency = 2
        linux: ->
        win32: ->
          process.stderr.write(fs.readFileSync('ci.log')) if error
          fs.unlinkSync('ci.log')

      callback(null, error)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    done = @async()
    startTime = Date.now()

    # TODO: This should really be parallel on both platforms, however our
    # fixtures step on each others toes currently.
    method = withPlatform
      darwin: -> async.parallel
      linux: -> async.series
      win32: -> async.series

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
