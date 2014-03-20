path = require 'path'
runas = null

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'install', 'Install the built application', ->
    installDir = grunt.config.get('atom.installDir')
    shellAppDir = grunt.config.get('atom.shellAppDir')
    if process.platform is 'win32'
      runas ?= require 'runas'
      copyFolder = path.resolve 'script', 'copy-folder.cmd'
      if runas('cmd', ['/c', copyFolder, shellAppDir, installDir], admin: true) isnt 0
        grunt.log.error("Failed to copy #{shellAppDir} to #{installDir}")

      createShortcut = path.resolve 'script', 'create-shortcut.cmd'
      runas('cmd', ['/c', createShortcut, path.join(installDir, 'atom.exe'), 'Atom'])
    else if process.platform is 'darwin'
      rm installDir
      mkdir path.dirname(installDir)
      cp shellAppDir, installDir
    else
      binDir = path.join(installDir, 'bin')
      shareDir = path.join(installDir, 'share')

      mkdir binDir
      cp 'atom.sh', path.join(binDir, 'atom')
      cp shellAppDir, shareDir
