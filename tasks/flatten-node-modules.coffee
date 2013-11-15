path = require 'path'
{cp, rm} = require './task-helpers'

module.exports = (grunt) ->
  grunt.registerTask 'flatten-node-modules', 'Flattens the node_modules to limit paths to 260 characters', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    done = @async()

    browserifyDir = path.join(shellAppDir, 'resources', 'app', 'node_modules',
      'grunt-coffeelint', 'node_modules', 'coffeelint', 'node_modules', 'browserify')
    toplevelBrowserifyDir = path.join(shellAppDir, 'resources', 'app', 'node_modules',
      'browserify')
    cp(browserifyDir, toplevelBrowserifyDir)
    rm(browserifyDir)

    options =
      cmd: 'npm'
      opts:
        cwd: shellAppDir
        stdio: 'inherit'
      args: ['dedupe']
    grunt.util.spawn(options, done)
