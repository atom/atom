fs = require 'fs'
path = require 'path'
rm = require('rimraf').sync
mkdir = require('wrench').mkdirSyncRecursive
cp = require('wrench').copyDirSyncRecursive
_ = require 'underscore'
CSON = require 'season'

BUILD_DIR = '/tmp/atom-build'
APP_NAME = 'Atom.app'
APP_DIR = path.join(BUILD_DIR, APP_NAME, 'Contents', 'Resources', 'app')
INSTALL_DIR = path.join('/Applications', APP_NAME)

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    coffee:
      options:
        sourceMap: true

      glob_to_multiple:
        expand: true
        src: [
          'src/**/*.coffee'
          'static/**/*.coffee'
          'vendor/**/*.coffee'
        ]
        dest: APP_DIR
        ext: '.js'

    less:
      options:
        paths: [
          'static'
          'vendor'
        ]
      glob_to_multiple:
        expand: true
        src: [
          'src/**/*.less'
          'static/**/*.less'
          'themes/**/*.less'
        ]
        dest: APP_DIR
        ext: '.css'

    cson:
      glob_to_multiple:
        expand: true
        src: [
          'src/**/*.cson'
          'static/**/*.cson'
          'themes/**/*.cson'
        ]
        dest: APP_DIR
        ext: '.json'

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
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')

  grunt.registerMultiTask 'cson', 'Compile CSON files to JSON', ->
    for mapping in @files
      source = mapping.src[0]
      destination = mapping.dest
      try
        object = CSON.readFileSync(source)
        if !_.isObject(object) or _.isArray(object)
          grunt.log.error("#{source} does not contain a root object")
          return false
        mkdir path.dirname(destination)
        CSON.writeFileSync(destination, object)
        grunt.log.writeln("File #{destination.cyan} created.")
      catch e
        grunt.log.error("Parsing #{source} failed: #{e.message}")
        return false

  grunt.registerTask 'clean', 'Delete all build files', ->
    rm BUILD_DIR
    rm '/tmp/atom-coffee-cache'
    rm '/tmp/atom-cached-atom-shells'
    rm 'node_modules'
    rm 'atom-shell'
    rm 'cef'
    rm 'node'
    rm 'prebuilt-cef'

  grunt.registerTask 'build', 'Build the application', ->
    rm BUILD_DIR
    mkdir BUILD_DIR
    cp 'atom-shell', path.join(BUILD_DIR, 'atom-shell')
    grunt.task.run('compile')

  grunt.registerTask 'install', 'Install the built application', ->
    rm INSTALL_DIR
    cp path.join(BUILD_DIR, APP_NAME), INSTALL_DIR

  grunt.registerTask('compile', ['coffee', 'less', 'cson'])
  grunt.registerTask('lint', ['coffeelint', 'csslint'])
  grunt.registerTask('default', ['lint', 'build'])
