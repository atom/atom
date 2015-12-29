fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  getVersion = (callback) ->
    releasableBranches = ['stable', 'beta']
    channel = grunt.config.get('atom.channel')
    shouldUseCommitHash = if channel in releasableBranches then false else true
    inRepository = fs.existsSync(path.resolve(__dirname, '..', '..', '.git'))
    {version} = require(path.join(grunt.config.get('atom.appDir'), 'package.json'))
    if shouldUseCommitHash and inRepository
      cmd = 'git'
      args = ['rev-parse', '--short', 'HEAD']
      spawn {cmd, args}, (error, {stdout}={}, code) ->
        commitHash = stdout?.trim?()
        combinedVersion = "#{version}-#{commitHash}"
        callback(error, combinedVersion)
    else
      callback(null, version)

  grunt.registerTask 'set-version', 'Set the version in the plist and package.json', ->
    done = @async()

    getVersion (error, version) ->
      if error?
        done(error)
        return

      appDir = grunt.config.get('atom.appDir')
      shellAppDir = grunt.config.get('atom.shellAppDir')

      # Replace version field of package.json.
      packageJsonPath = path.join(appDir, 'package.json')
      packageJson = require(packageJsonPath)
      packageJson.version = version
      packageJsonString = JSON.stringify(packageJson)
      fs.writeFileSync(packageJsonPath, packageJsonString)

      if process.platform is 'darwin'
        cmd = 'script/set-version'
        args = [shellAppDir, version]
        spawn {cmd, args}, (error, result, code) -> done(error)
      else if process.platform is 'win32'
        shellAppDir = grunt.config.get('atom.shellAppDir')
        shellExePath = path.join(shellAppDir, 'atom.exe')

        strings =
          CompanyName: 'GitHub, Inc.'
          FileDescription: 'Atom'
          LegalCopyright: 'Copyright (C) 2015 GitHub, Inc. All rights reserved'
          ProductName: 'Atom'
          ProductVersion: version

        rcedit = require('rcedit')
        rcedit(shellExePath, {'version-string': strings}, done)
      else
        done()
