{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  APP_NAME = "Atom.app"
  BUILD_DIR = grunt.option('build-dir') ? "/tmp/atom-build/"
  SHELL_APP_DIR = path.join(BUILD_DIR, APP_NAME)
  CONTENTS_DIR = path.join(SHELL_APP_DIR, 'Contents')
  APP_DIR = path.join(CONTENTS_DIR, "Resources", "app")
  INSTALL_DIR = path.join('/Applications', APP_NAME)

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
      options:
        rootObject: true
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
        no_empty_param_list:
          level: 'error'
        max_line_length:
          level: 'ignore'

      src: [
        'dot-atom/**/*.coffee'
        'src/**/*.coffee'
      ]
      test: [
        'spec/*.coffee'
        'spec/app/**/*.coffee'
        'spec/stdlib/**/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
        'box-model': false
        'box-sizing': false
        'bulletproof-font-face': false
        'compatible-vendor-prefixes': false
        'fallback-colors': false
        'font-sizes': false
        'gradients': false
        'ids': false
        'important': false
        'known-properties': false
        'outline-none': false
        'overqualified-elements': false
        'qualified-headings': false
        'unique-headings': false
        'universal-selector': false
        'vendor-prefix': false
      src: [
        'src/**/*.css',
        'static/**/*.css'
        'themes/**/*.css'
      ]

    lesslint:
      src: [
        'src/**/*.less',
        'static/**/*.less'
        'themes/**/*.less'
      ]

  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')

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
    mkdir path.dirname(BUILD_DIR)
    cp 'atom-shell/Atom.app', BUILD_DIR

    mkdir APP_DIR

    cp 'atom.sh', path.join(APP_DIR, 'atom.sh')
    cp 'package.json', path.join(APP_DIR, 'package.json')

    directories = [
      'benchmark'
      'dot-atom'
      'node_modules'
      'spec'
      'vendor'
    ]
    cp directory, path.join(APP_DIR, directory) for directory in directories

    cp 'src', path.join(APP_DIR, 'src'), filter: /.+\.(cson|coffee|less)$/
    cp 'static', path.join(APP_DIR, 'static'), filter: /.+\.less$/
    cp 'themes', path.join(APP_DIR, 'themes'), filter: /.+\.(cson|less)$/

    grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
      unless /.+\.plist/.test(sourcePath)
        grunt.file.copy(sourcePath, path.resolve(APP_DIR, '..', subDirectory, filename))

    grunt.task.run('compile', 'update-info-plist', 'codesign')

  grunt.registerTask 'update-info-plist', 'Copy plist and set version to current sha', ->
    done = @async()
    grunt.util.spawn cmd: 'script/update-info-plist', args: [BUILD_DIR], (error, result, code) ->
      done(!error?)

  grunt.registerTask 'codesign', 'Codesign the app', ->
    done = @async()
    args = ["-f", "-v", "-s", "Developer ID Application: GitHub", SHELL_APP_DIR]
    grunt.util.spawn cmd: "codesign", args: args, (error) -> done(!error?)

  grunt.registerTask 'install', 'Install the built application', ->
    rm INSTALL_DIR
    mkdir path.dirname(INSTALL_DIR)
    cp SHELL_APP_DIR, INSTALL_DIR

  grunt.registerTask 'bootstrap', 'Bootstrap modules and atom-shell', ->
    done = @async()
    commands = []
    commands.push (callback) ->
      grunt.util.spawn cmd: 'script/bootstrap', callback
    commands.push (result, callback) ->
      grunt.util.spawn cmd: 'script/update-atom-shell', callback
    grunt.util.async.waterfall commands, (error) -> done(!error?)

  grunt.registerTask 'test', 'Run the specs', ->
    done = @async()
    commands = []
    commands.push (callback) ->
      grunt.util.spawn cmd: 'pkill', args: ['Atom'], -> callback()
    commands.push (result, callback) ->
      atomBinary = path.join(CONTENTS_DIR, 'MacOS', 'Atom')
      grunt.util.spawn cmd: atomBinary, args: ['--test', "--resource-path=#{__dirname}"], callback
    grunt.util.async.waterfall commands, (error) -> done(!error?)

  grunt.registerTask('compile', ['coffee', 'less', 'cson'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('ci', ['clean', 'bootstrap', 'build', 'test'])
  grunt.registerTask('default', ['build'])

  cp = (source, destination, {filter}={}) ->
    copyFile = (source, destination) ->
      if grunt.file.isLink(source)
        grunt.file.mkdir(path.dirname(destination))
        fs.symlinkSync(fs.readlinkSync(source), destination)
      else
        grunt.file.copy(source, destination)

      if grunt.file.exists(destination)
        fs.chmodSync(destination, fs.statSync(source).mode)

    if grunt.file.isDir(source)
      grunt.file.recurse source, (sourcePath, rootDirectory, subDirectory='', filename) ->
        unless filter?.test(sourcePath)
          copyFile(sourcePath, path.join(destination, subDirectory, filename))
    else
      copyFile(source, destination)

    grunt.log.writeln("Copied #{source.cyan} to #{destination.cyan}.")

  mkdir = (args...) -> grunt.file.mkdir(args...)
  rm = (args...) ->
    grunt.file.delete(args..., force: true) if grunt.file.exists(args...)
