path = require 'path'
fs = require 'fs'
wrench = require 'wrench'

module.exports = (grunt) ->
  grunt.registerTask 'flatten-node-modules', 'Flattens the node_modules to limit paths to 260 characters', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    done = @async()

    browserifyDir = path.join(shellAppDir, 'resources', 'app', 'node_modules',
      'grunt-coffeelint', 'node_modules', 'coffeelint', 'node_modules', 'browserify')
    toplevelBrowserifyDir = path.join(shellAppDir, 'resources', 'app', 'node_modules',
      'browserify')
    wrench.copyDirSyncRecursive(browserifyDir, toplevelBrowserifyDir)
    wrench.rmdirSyncRecursive(browserifyDir)

    options =
      cmd: 'npm'
      opts:
        cwd: shellAppDir
        stdio: 'inherit'
      args: ['dedupe']
    grunt.util.spawn(options, done)
