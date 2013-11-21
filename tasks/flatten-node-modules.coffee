path = require 'path'
{cp, rm} = require './task-helpers'

module.exports = (grunt) ->
  grunt.registerTask 'flatten-node-modules', 'Flattens the node_modules to limit paths to 260 characters', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    done = @async()

    toplevelNodeModulesDir = path.join(shellAppDir, 'resources', 'app', 'node_modules')
    browserifyDir = path.join(toplevelNodeModulesDir,'grunt-coffeelint', 'node_modules',
     'coffeelint', 'node_modules', 'browserify')

    cp(browserifyDir, path.join(toplevelNodeModulesDir, 'browserify'))
    rm(browserifyDir)

    options =
      cmd: 'npm'
      opts:
        cwd: path.join(toplevelNodeModulesDir, '..')
        stdio: 'inherit'
      args: ['dedupe']
    grunt.util.spawn(options, done)
