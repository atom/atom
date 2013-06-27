module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'partial-clean', 'Delete some of the build files', ->
    rm grunt.config.get('globals.buildDir')
    rm '/tmp/atom-coffee-cache'
    rm '/tmp/atom-cached-atom-shells'
    rm 'node'

  grunt.registerTask 'clean', 'Delete all the build files', ->
    rm 'node_modules'
    grunt.task.run('partial-clean')
