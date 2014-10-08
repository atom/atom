path = require 'path'
ModuleCache = require '../../src/module-cache'

module.exports = (grunt) ->
  grunt.registerTask 'generate-module-cache', 'Generate a module cache for all core modules and packages', ->
    appDir = grunt.config.get('atom.appDir')

    {packageDependencies} = grunt.file.readJSON('package.json')

    for packageName, version of packageDependencies
      ModuleCache.create(path.join(appDir, 'node_modules', packageName))

    ModuleCache.create(appDir)

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))

    metadata._atomModuleCache.folders.forEach (folder) ->
      if '' in folder.paths
        folder.paths = [
          ''
          'exports'
          'spec'
          'src'
          'src/browser'
          'static'
          'vendor'
        ]

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata, null, 2))
