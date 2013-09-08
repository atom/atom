path = require 'path'

module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'partial-clean', 'Delete some of the build files', ->
    rm grunt.config.get('atom.buildDir')
    rm '/tmp/atom-compile-cache'
    rm '/tmp/atom-cached-atom-shells'
    rm 'atom-shell'

  grunt.registerTask 'clean', 'Delete all the build files', ->
    rm 'node_modules'
    rm path.join(process.env.HOME, '.atom', '.node-gyp')
    grunt.task.run('partial-clean')
