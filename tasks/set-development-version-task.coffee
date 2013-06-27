module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'set-development-version', 'Sets version to current SHA-1', ->
    done = @async()
    cmd = 'script/set-version'
    args = [grunt.config.get('atom.buildDir')]
    spawn {cmd, args}, (error, result, code) -> done(error)
