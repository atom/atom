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
      themeMains = []
      for theme in configuration
        # TODO Use AtomPackage class once it runs outside of an Atom context
        themePath = path.resolve('node_modules', theme)
        stylesheetsDir = path.join(themePath, 'stylesheets')
        {main} = grunt.file.readJSON(path.join(themePath, 'package.json'))
        main ?= 'index.less'
        mainPath = path.join(themePath, main)
        themeMains.push(mainPath) if grunt.file.isFile(mainPath)
        importPaths.unshift(stylesheetsDir) if grunt.file.isDir(stylesheetsDir)

      grunt.log.writeln("Building LESS cache for #{configuration.join(', ').yellow}")
      lessCache = new LessCache
        cacheDir: directory
        resourcePath: path.resolve('.')
        importPaths: importPaths

      for file in @filesSrc
        grunt.log.writeln("File #{file.cyan} created in cache.")
        lessCache.readFileSync(file)

      for file in themeMains
        grunt.log.writeln("File #{file.cyan} created in cache.")
        lessCache.readFileSync(file)
