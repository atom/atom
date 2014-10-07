ModuleCache = require '../../src/module-cache'

module.exports = (grunt) ->
  grunt.registerTask 'generate-module-cache', 'Generate a module cache for all core modules', ->
    ModuleCache.generateDependencies(process.cwd())
