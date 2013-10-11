fs = require 'fs'
path = require 'path'

_ = require 'underscore'
async = require 'async'

module.exports = (grunt) ->
  {isAtomPackage, spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'run-specs', 'Run the specs', ->
    passed = true
    done = @async()
    appDir = grunt.config.get('atom.appDir')
    rootDir = grunt.config.get('atom.shellAppDir')
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

    queue.concurrency = 2
    queue.drain = -> done(passed)
