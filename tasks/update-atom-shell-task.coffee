module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'update-atom-shell', 'Update atom-shell', ->
    done = @async()
    spawn cmd: 'script/update-atom-shell', (error) -> done(error)
