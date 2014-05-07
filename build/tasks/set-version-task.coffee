fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  getVersion = (callback) ->
    onBuildMachine = process.env.JANKY_SHA1 and process.env.JANKY_BRANCH is 'master'
    inRepository = fs.existsSync(path.resolve(__dirname, '..', '..', '.git'))
    if onBuildMachine or not inRepository
      {version} = require(path.join(grunt.config.get('atom.appDir'), 'package.json'))
      callback(null, version)
    else
      cmd = 'git'
      args = ['rev-parse', '--short', 'HEAD']
      spawn {cmd, args}, (error, {stdout}={}, code) ->
        callback(error, stdout?.trim?())

  grunt.registerTask 'set-version', 'Set the version in the plist and package.json', ->
    done = @async()

    getVersion (error, version) ->
      if error?
        done(error)
        return

      appDir = grunt.config.get('atom.appDir')

      # Replace version field of package.json.
      packageJsonPath = path.join(appDir, 'package.json')
      packageJson = require(packageJsonPath)
      packageJson.version = version
      packageJsonString = JSON.stringify(packageJson, null, 2)
      fs.writeFileSync(packageJsonPath, packageJsonString)

      if process.platform is 'darwin'
        cmd = 'script/set-version'
        args = [grunt.config.get('atom.buildDir'), version]
        spawn {cmd, args}, (error, result, code) -> done(error)
      else if process.platform is 'win32'
        shellAppDir = grunt.config.get('atom.shellAppDir')
        shellExePath = path.join(shellAppDir, 'atom.exe')

        strings =
          CompanyName: 'GitHub, Inc.'
          FileDescription: 'The hackable editor'
          LegalCopyright: 'Copyright (C) 2013 GitHub, Inc. All rights reserved'
          ProductName: 'Atom'
          ProductVersion: version

        rcedit = require('rcedit')
        rcedit(shellExePath, {'version-string': strings}, done)
      else
        done()
