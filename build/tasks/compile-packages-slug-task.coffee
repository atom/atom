path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'compile-packages-slug', 'Add package metadata information to to the main package.json file', ->
    appDir = grunt.config.get('atom.appDir')

    modulesDirectory = path.join(appDir, 'node_modules')
    packages = {}

    for moduleDirectory in fs.listSync(modulesDirectory)
      continue if path.basename(moduleDirectory) is '.bin'

      metadata = grunt.file.readJSON(path.join(moduleDirectory, 'package.json'))
      continue unless metadata?.engines?.atom?

      pack = {metadata, keymaps: {}, menus: {}}

      for keymapPath in fs.listSync(path.join(moduleDirectory, 'keymaps'), ['.cson', '.json'])
        relativePath = path.relative(appDir, keymapPath)
        pack.keymaps[relativePath] = CSON.readFileSync(keymapPath)

      for menuPath in fs.listSync(path.join(moduleDirectory, 'menus'), ['.cson', '.json'])
        relativePath = path.relative(appDir, menuPath)
        pack.menus[relativePath] = CSON.readFileSync(menuPath)

      packages[metadata.name] = pack

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))
    metadata._atomPackages = packages

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata, null, 2))
