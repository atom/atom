fs = require 'fs'
path = require 'path'

_ = require 'underscore'
async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  runPackageSpecs = (callback) ->
    passed = true
    rootDir = grunt.config.get('atom.shellAppDir')
    appDir = grunt.config.get('atom.appDir')
    atomPath = path.join(appDir, 'atom.sh')
    apmPath = path.join(appDir, 'node_modules/.bin/apm')

    queue = async.queue (packagePath, callback) ->
      options =
        cmd: apmPath
        args: ['test', '--path', atomPath]
        opts:
          cwd: packagePath
          env: _.extend({}, process.env, ATOM_PATH: rootDir)
      grunt.log.writeln("Launching #{path.basename(packagePath)} specs.")
      spawn options, (error, results, code) ->
        passed = passed and code is 0
        callback()

    modulesDirectory = path.resolve('node_modules')
    for packageDirectory in fs.readdirSync(modulesDirectory)
      packagePath = path.join(modulesDirectory, packageDirectory)
      continue unless grunt.file.isDir(path.join(packagePath, 'spec'))
      continue unless isAtomPackage(packagePath)
      queue.push(packagePath)

    queue.concurrency = 1
    queue.drain = -> callback(passed)

  runCoreSpecs = (callback) ->
    contentsDir = grunt.config.get('atom.contentsDir')
    appPath = path.join(contentsDir, 'MacOS', 'Atom')
    resourcePath = process.cwd()
    coreSpecsPath = path.resolve('spec')

    options =
      cmd: appPath
      args: ['--test', "--resource-path=#{resourcePath}", "--spec-directory=#{coreSpecsPath}"]
    spawn options, (error, results, code) ->
      callback(code is 0)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    passed = true
    async.parallel([runCoreSpecs, runPackageSpecs], @async())
