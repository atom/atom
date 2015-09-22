path = require 'path'
fs = require 'fs-plus'
runas = null
temp = require 'temp'

module.exports = (grunt) ->
  {cp, fillTemplate, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'install', 'Install the built application', ->
    appName = grunt.config.get('atom.appName')
    appFileName = grunt.config.get('atom.appFileName')
    apmFileName = grunt.config.get('atom.apmFileName')
    buildDir = grunt.config.get('atom.buildDir')
    installDir = grunt.config.get('atom.installDir')
    shellAppDir = grunt.config.get('atom.shellAppDir')
    {description} = grunt.config.get('atom.metadata')

    if process.platform is 'win32'
      runas ?= require 'runas'
      copyFolder = path.resolve 'script', 'copy-folder.cmd'
      if runas('cmd', ['/c', copyFolder, shellAppDir, installDir], admin: true) isnt 0
        grunt.log.error("Failed to copy #{shellAppDir} to #{installDir}")

      createShortcut = path.resolve 'script', 'create-shortcut.cmd'
      runas('cmd', ['/c', createShortcut, path.join(installDir, 'atom.exe'), appName])
    else if process.platform is 'darwin'
      rm installDir
      mkdir path.dirname(installDir)

      tempFolder = temp.path()
      mkdir tempFolder
      cp shellAppDir, tempFolder
      fs.renameSync(tempFolder, installDir)
    else
      shareDir = path.join(installDir, 'share', appFileName)
      rm shareDir
      mkdir path.dirname(shareDir)
      cp shellAppDir, shareDir

      unless installDir.indexOf(process.env.TMPDIR ? '/tmp') is 0
        iconPath = path.join(shareDir, 'resources', 'app.asar.unpacked', 'resources', 'atom.png')

        mkdir path.join(installDir, 'share', 'applications')
        fillTemplate(
          path.join('resources', 'linux', 'atom.desktop.in'),
          path.join(installDir, 'share', 'applications', appFileName + '.desktop'),
          {appName, appFileName, description, iconPath, installDir}
        )

      binDir = path.join(installDir, 'bin')
      mkdir binDir
      cp 'atom.sh', path.join(binDir, appFileName)

      rm(path.join(binDir, apmFileName))
      fs.symlinkSync(
        path.join('..', 'share', appFileName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'),
        path.join(binDir, apmFileName)
      )

      fs.chmodSync(path.join(shareDir, 'atom'), '755')
