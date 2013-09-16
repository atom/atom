path = require 'path'

LessCache = require 'less-cache'

module.exports = (grunt) ->
  grunt.registerMultiTask 'prebuild-less', 'Prebuild cached of compiled LESS files', ->
    prebuiltConfigurations = [
      ['atom-dark-ui', 'atom-dark-syntax']
      ['atom-dark-ui', 'atom-light-syntax']
      ['atom-light-ui', 'atom-light-syntax']
      ['atom-light-ui', 'atom-dark-syntax']
    ]

    directory = path.join(grunt.config.get('atom.appDir'), 'less-compile-cache')

    for configuration in prebuiltConfigurations
      importPaths = [
        path.resolve('static/variables')
        path.resolve('static')
        path.resolve('vendor')
      ]
      for theme in configuration
        # TODO Using AtomPackage class once it runs outside of an Atom context
        themePath = path.resolve('node_modules', theme, 'stylesheets')
        importPaths.unshift(themePath) if grunt.file.isDir(themePath)

      grunt.log.writeln("Building LESS cache for #{configuration.join(', ').yellow}")
      lessCache = new LessCache
        cacheDir: directory
        resourcePath: path.resolve('.')
        importPaths: importPaths

      for file in @filesSrc
        grunt.log.writeln("File #{file.cyan} created in cache.")
        lessCache.readFileSync(file)
