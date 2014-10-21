path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'compile-packages-slug', 'Add bundled package metadata information to the main package.json file', ->
    appDir = fs.realpathSync(grunt.config.get('atom.appDir'))

    modulesDirectory = path.join(appDir, 'node_modules')
    packages = {}

    for moduleDirectory in fs.listSync(modulesDirectory)
      continue if path.basename(moduleDirectory) is '.bin'

      metadataPath = path.join(moduleDirectory, 'package.json')
      metadata = grunt.file.readJSON(metadataPath)
      continue unless metadata?.engines?.atom?

      moduleCache = metadata._atomModuleCache ? {}

      rm metadataPath
      _.remove(moduleCache.extensions?['.json'] ? [], 'package.json')

      for property in ['_from', '_id', 'dist', 'readme', 'readmeFilename']
        delete metadata[property]

      pack = {metadata, keymaps: {}, menus: {}}

      if metadata.main
        mainPath = require.resolve(path.resolve(moduleDirectory, metadata.main))
        pack.main = path.relative(appDir, mainPath)

      for keymapPath in fs.listSync(path.join(moduleDirectory, 'keymaps'), ['.cson', '.json'])
        relativePath = path.relative(appDir, keymapPath)
        pack.keymaps[relativePath] = CSON.readFileSync(keymapPath)
        rm keymapPath

      for menuPath in fs.listSync(path.join(moduleDirectory, 'menus'), ['.cson', '.json'])
        relativePath = path.relative(appDir, menuPath)
        pack.menus[relativePath] = CSON.readFileSync(menuPath)
        rm menuPath

      packages[metadata.name] = pack

      for extension, paths of moduleCache.extensions
        delete moduleCache.extensions[extension] if paths.length is 0

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))
    metadata._atomPackages = packages

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata))
