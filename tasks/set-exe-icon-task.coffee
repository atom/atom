path = require 'path'

module.exports = (grunt) ->
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'set-exe-icon', 'Set icon of the exe', ->
    done = @async()

    shellAppDir = grunt.config.get('atom.shellAppDir')
    appDir = grunt.config.get('atom.appDir')
    shellExePath = path.join(shellAppDir, 'atom.exe')
    iconPath = path.resolve(__dirname, '..', 'resources', 'win', 'atom.ico')
    pngPath = path.resolve(__dirname, '..', 'resources', 'win', 'atom.png')

    cp pngPath, path.join(appDir, 'atom.png')

    rcedit = require('rcedit')
    rcedit(shellExePath, {'icon': iconPath}, done)
