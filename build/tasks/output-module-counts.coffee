path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'output-module-counts', 'Log modules where more than one copy exists in node_modules', ->
    nodeModulesDir = path.resolve(__dirname, '..', '..', 'node_modules')

    modules = {}
    grunt.file.recurse nodeModulesDir, (absolutePath, rootPath, relativePath, fileName) ->
      return if fileName isnt 'package.json'

      {name} = grunt.file.readJSON(absolutePath)
      modules[name] ?= 0
      modules[name]++

    sortedNames = Object.keys(modules).sort (name1, name2) ->
      diff = modules[name2] - modules[name1]
      diff = name1.localeCompare(name2) if diff is 0
      diff

    sortedNames.forEach (name) ->
      count = modules[name]
      grunt.log.error "#{name}: #{count}" if count > 1
