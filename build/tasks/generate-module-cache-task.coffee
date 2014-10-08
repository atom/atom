path = require 'path'
ModuleCache = require '../../src/module-cache'

module.exports = (grunt) ->
  grunt.registerTask 'generate-module-cache', 'Generate a module cache for all core modules and packages', ->
    {packageDependencies} = grunt.file.readJSON('package.json')

    for packageName, version of packageDependencies
      ModuleCache.create(path.join(process.cwd(), 'node_modules', packageName))

    ModuleCache.create(process.cwd())
