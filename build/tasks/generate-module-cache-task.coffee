path = require 'path'
fs = require 'fs-plus'
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

    # Reactionary does not have an explicit react dependency
    metadata._atomModuleCache.folders.push
      paths: [
        'node_modules/reactionary-atom-fork/lib'
      ]
      dependencies: {
        'react-atom-fork': metadata.dependencies['react-atom-fork']
      }

    validExtensions = ['.js', '.coffee', '.json', '.node']

    extensions = {}
    onFile = (filePath) ->
      filePath = path.relative(appDir, filePath)
      segments = filePath.split(path.sep)
      return if segments.length > 1 and not (segments[0] in ['exports', 'node_modules', 'src', 'static', 'vendor'])

      extension = path.extname(filePath)
      if extension in validExtensions
        extensions[extension] ?= []
        extensions[extension].push(filePath)

    onDirectory = -> true

    files = fs.traverseTreeSync(appDir, onFile, onDirectory)

    metadata._atomModuleCache.extensions = extensions

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata, null, 2))
