path = require 'path'
fs = require 'fs'

LessCache = require 'less-cache'

module.exports = (grunt) ->
  grunt.registerMultiTask 'prebuild-less', 'Prebuild cached of compiled LESS files', ->
    prebuiltConfigurations = [
      ['atom-dark-ui', 'atom-dark-syntax']
      ['atom-dark-ui', 'atom-light-syntax']
      ['atom-dark-ui', 'solarized-dark-syntax']
      ['atom-dark-ui', 'base16-tomorrow-dark-theme']
      ['atom-dark-ui', 'base16-tomorrow-light-theme']
      ['atom-light-ui', 'atom-light-syntax']
      ['atom-light-ui', 'atom-dark-syntax']
      ['atom-light-ui', 'solarized-dark-syntax']
      ['atom-light-ui', 'base16-tomorrow-dark-theme']
      ['atom-light-ui', 'base16-tomorrow-light-theme']
    ]

    directory = path.join(grunt.config.get('atom.appDir'), 'less-compile-cache')

    for configuration in prebuiltConfigurations
      importPaths = grunt.config.get('less.options.paths')
      themeMains = []
      for theme in configuration
        # TODO Use AtomPackage class once it runs outside of an Atom context
        themePath = path.resolve('node_modules', theme)
        if fs.existsSync(path.join(themePath, 'stylesheets'))
          stylesheetsDir = path.join(themePath, 'stylesheets')
        else
          stylesheetsDir = path.join(themePath, 'styles')
        {main} = grunt.file.readJSON(path.join(themePath, 'package.json'))
        main ?= 'index.less'
        mainPath = path.join(themePath, main)
        themeMains.push(mainPath) if grunt.file.isFile(mainPath)
        importPaths.unshift(stylesheetsDir) if grunt.file.isDir(stylesheetsDir)

      grunt.verbose.writeln("Building LESS cache for #{configuration.join(', ').yellow}")
      lessCache = new LessCache
        cacheDir: directory
        resourcePath: path.resolve('.')
        importPaths: importPaths

      for file in @filesSrc
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        lessCache.readFileSync(file)

      for file in themeMains
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        lessCache.readFileSync(file)
