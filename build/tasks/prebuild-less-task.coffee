path = require 'path'
fs = require 'fs'
temp = require('temp').track()
LessCache = require 'less-cache'

module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)
  cacheMisses = 0
  cacheHits = 0

  compileBootstrap = ->
    appDir = grunt.config.get('atom.appDir')
    bootstrapLessPath = path.join(appDir, 'static', 'bootstrap.less')
    bootstrapCssPath = path.join(appDir, 'static', 'bootstrap.css')

    lessCache = new LessCache
      cacheDir: temp.mkdirSync('atom-less-cache')
      fallbackDir: grunt.config.get('prebuild-less.options.cachePath')
      syncCaches: true
      resourcePath: path.resolve('.')

    bootstrapCss = lessCache.readFileSync(bootstrapLessPath)
    grunt.file.write(bootstrapCssPath, bootstrapCss)
    rm(bootstrapLessPath)
    rm(path.join(appDir, 'node_modules', 'bootstrap', 'less'))
    cacheMisses += lessCache.stats.misses
    cacheHits += lessCache.stats.hits

  importFallbackVariables = (lessFilePath) ->
    if lessFilePath.indexOf('static') is 0
      false
    else
      true

  grunt.registerMultiTask 'prebuild-less', 'Prebuild cached of compiled Less files', ->
    compileBootstrap()

    uiThemes = [
      'atom-dark-ui'
      'atom-light-ui'
      'one-dark-ui'
      'one-light-ui'
    ]

    syntaxThemes = [
      'atom-dark-syntax'
      'atom-light-syntax'
      'one-dark-syntax'
      'one-light-syntax'
      'solarized-dark-syntax'
      'base16-tomorrow-dark-theme'
      'base16-tomorrow-light-theme'
    ]

    prebuiltConfigurations = []
    uiThemes.forEach (uiTheme) ->
      syntaxThemes.forEach (syntaxTheme) ->
        prebuiltConfigurations.push([uiTheme, syntaxTheme])

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

      grunt.verbose.writeln("Building Less cache for #{configuration.join(', ').yellow}")
      lessCache = new LessCache
        cacheDir: directory
        fallbackDir: grunt.config.get('prebuild-less.options.cachePath')
        syncCaches: true
        resourcePath: path.resolve('.')
        importPaths: importPaths

      cssForFile = (file) ->
        less = fs.readFileSync(file, 'utf8')
        if importFallbackVariables(file)
          baseVarImports = """
          @import "variables/ui-variables";
          @import "variables/syntax-variables";
          """
          less = [baseVarImports, less].join('\n')
        lessCache.cssForFile(file, less)

      for file in @filesSrc
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        cssForFile(file)

      for file in themeMains
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        cssForFile(file)

      cacheMisses += lessCache.stats.misses
      cacheHits += lessCache.stats.hits

    grunt.log.ok("#{cacheMisses} files compiled, #{cacheHits} files reused")
