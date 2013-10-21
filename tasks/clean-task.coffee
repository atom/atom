path = require 'path'
os = require 'os'

module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'partial-clean', 'Delete some of the build files', ->
    tmpdir = if process.platform is 'win32' then os.tmpdir() else '/tmp'

    rm grunt.config.get('atom.buildDir')
    rm require('../src/coffee-cache').cacheDir
    rm require('../src/less-compile-cache').cacheDir
    rm path.join(tmpdir, 'atom-cached-atom-shells')
    rm 'atom-shell'

  grunt.registerTask 'clean', 'Delete all the build files', ->
    rm 'node_modules'
    rm path.join(process.env.HOME, '.atom', '.node-gyp')
    grunt.task.run('partial-clean')
