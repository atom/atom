path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  getAtomShellVersion = ->
    versionPath = path.join('atom-shell', 'version')
    if grunt.file.isFile(versionPath)
      grunt.file.read(versionPath).trim()
    else
      null

  grunt.registerTask 'update-atom-shell', 'Update atom-shell', ->
    done = @async()
    currentVersion = getAtomShellVersion()
    spawn cmd: 'script/update-atom-shell', (error) ->
      if error?
        done(error)
      else
        newVersion = getAtomShellVersion()
        if newVersion and currentVersion isnt newVersion
          grunt.log.writeln("Rebuilding native modules for new atom-shell version #{newVersion.cyan}.")
          cmd = path.join('node_modules', '.bin', 'apm')
          spawn {cmd, args: ['rebuild']}, (error) -> done(error)
        else
          done()
