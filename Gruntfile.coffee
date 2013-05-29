BUILD_DIR = '/tmp/atom-build'

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    coffeelint:
      options:
        max_line_length:
          level: 'ignore'

      src: ['src/**/*.coffee']
      test: [
        'spec/*.coffee'
        'spec/app/**/*.coffee'
        'spec/stdlib/**/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
        'fallback-colors': false
      src: ['themes/**/*.css', 'src/**/*.css']

  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-contrib-csslint')

  grunt.registerTask 'clean', 'Delete all build files', ->
    rm = require('rimraf').sync
    rm BUILD_DIR
    rm '/tmp/atom-coffee-cache'
    rm '/tmp/atom-cached-atom-shells'
    rm 'node_modules'
    rm 'atom-shell'
    rm 'cef'
    rm 'node'
    rm 'prebuilt-cef'

  grunt.registerTask('lint', ['coffeelint:src', 'coffeelint:test', 'csslint:src'])
  grunt.registerTask('default', 'lint')
