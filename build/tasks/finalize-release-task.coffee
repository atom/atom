child_process = require('child_process')

module.exports = (grunt) ->
  grunt.registerTask 'finalize-release', 'Request for this release to be finalized on AppVeyor', ->
    unless process.platform is 'win32' and process.env.APPVEYOR
      throw new Error('This task should only be run on AppVeyor')

    unless grunt.config.get('atom.channel') in ['beta', 'stable']
      throw new Error('This taks should only be run in a beta/stable release channel build')

    doneCallback = @async()

    startBuildCommand = 'appveyor Start-AppveyorBuild '
    startBuildCommand += "-ApiKey #{process.env.APPVEYOR_API_KEY}"
    startBuildCommand += "-AccountName Atom -ProjectSlug atom-release-finalizer"
    grunt.log.ok('Requesting release build via: ' + startBuildCommand)

    child_process.exec startBuildCommand, (error, stdout, stderr) ->
      if error?
        grunt.log.error(stderr)
      else
        grunt.log.ok(stdout)
      doneCallback(error)
