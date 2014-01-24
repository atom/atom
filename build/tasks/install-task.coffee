path = require 'path'

module.exports = (grunt) ->
  {cp, mkdir, rm, spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'install', 'Install the built application', ->
    installDir = grunt.config.get('atom.installDir')
    shellAppDir = grunt.config.get('atom.shellAppDir')
    if process.platform is 'win32'
      done = @async()

      runas = require 'runas'
      copyFolder = path.resolve 'script', 'copy-folder.cmd'
      # cmd /c ""script" "source" "destination""
      arg = "/c \"\"#{copyFolder}\" \"#{shellAppDir}\" \"#{installDir}\"\""
      if runas('cmd', [arg], hide: true) isnt 0
        done("Failed to copy #{shellAppDir} to #{installDir}")

      createShortcut = path.resolve 'script', 'create-shortcut.cmd'
      args = ['/c', createShortcut, path.join(installDir, 'atom.exe'), 'Atom']
      spawn {cmd: 'cmd', args}, done
    else
      rm installDir
      mkdir path.dirname(installDir)
      cp shellAppDir, installDir
