module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'nof', 'Un-focus all specs', ->
    nof = require.resolve('.bin/nof')
    spawn({cmd: nof, args: ['spec']}, @async())
