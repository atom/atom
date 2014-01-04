module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'codesign', 'Codesign the app', ->
    done = @async()
    cmd = 'codesign'
    args = ['-f', '-v', '-s', 'Developer ID Application: GitHub', grunt.config.get('atom.shellAppDir')]
    spawn {cmd, args}, (error) -> done(error)
