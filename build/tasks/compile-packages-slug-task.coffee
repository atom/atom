path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
_ = require 'underscore-plus'
normalizePackageData = require 'normalize-package-data'
semver = require 'semver'

OtherPlatforms = ['darwin', 'freebsd', 'linux', 'sunos', 'win32'].filter (platform) -> platform isnt process.platform

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  getMenu = (appDir) ->
    menusPath = path.join(appDir, 'menus')
    menuPath = path.join(menusPath, "#{process.platform}.json")
    menu = CSON.readFileSync(menuPath) if fs.isFileSync(menuPath)
    rm menusPath
    menu

  getKeymaps = (appDir) ->
    keymapsPath = path.join(appDir, 'keymaps')
    keymaps = {}
    for keymapPath in fs.listSync(keymapsPath, ['.json'])
      name = path.basename(keymapPath, path.extname(keymapPath))
      continue unless OtherPlatforms.indexOf(name) is -1

      keymap = CSON.readFileSync(keymapPath)
      keymaps[path.basename(keymapPath)] = keymap
    rm keymapsPath
    keymaps

  grunt.registerTask 'compile-packages-slug', 'Add bundled package metadata information to the main package.json file', ->
    appDir = fs.realpathSync(grunt.config.get('atom.appDir'))

    modulesDirectory = path.join(appDir, 'node_modules')
    packages = {}
    invalidPackages = false

    for moduleDirectory in fs.listSync(modulesDirectory)
      continue if path.basename(moduleDirectory) is '.bin'

      metadataPath = path.join(moduleDirectory, 'package.json')
      continue unless fs.existsSync(metadataPath)

      metadata = grunt.file.readJSON(metadataPath)
      continue unless metadata?.engines?.atom?

      reportPackageError = (msg) ->
        invalidPackages = true
        grunt.log.error("#{metadata.name}: #{msg}")
      normalizePackageData metadata, reportPackageError, true
      if metadata.repository?.type is 'git'
        metadata.repository.url = metadata.repository.url?.replace(/^git\+/, '')

      moduleCache = metadata._atomModuleCache ? {}

      rm metadataPath
      _.remove(moduleCache.extensions?['.json'] ? [], 'package.json')

      for property in ['_from', '_id', 'dist', 'readme', 'readmeFilename']
        delete metadata[property]

      pack = {metadata, keymaps: {}, menus: {}}

      if metadata.main
        mainPath = require.resolve(path.resolve(moduleDirectory, metadata.main))
        pack.main = path.relative(appDir, mainPath)

      keymapsPath = path.join(moduleDirectory, 'keymaps')
      for keymapPath in fs.listSync(keymapsPath, ['.cson', '.json'])
        relativePath = path.relative(appDir, keymapPath)
        pack.keymaps[relativePath] = CSON.readFileSync(keymapPath)
        rm keymapPath
      rm keymapsPath if fs.listSync(keymapsPath).length is 0

      menusPath = path.join(moduleDirectory, 'menus')
      for menuPath in fs.listSync(menusPath, ['.cson', '.json'])
        relativePath = path.relative(appDir, menuPath)
        pack.menus[relativePath] = CSON.readFileSync(menuPath)
        rm menuPath
      rm menusPath if fs.listSync(menusPath).length is 0

      packages[metadata.name] = pack

      for extension, paths of moduleCache.extensions
        delete moduleCache.extensions[extension] if paths.length is 0

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))
    metadata._atomPackages = packages
    metadata._atomMenu = getMenu(appDir)
    metadata._atomKeymaps = getKeymaps(appDir)
    metadata._deprecatedPackages = require('../deprecated-packages')

    for name, {version} of metadata._deprecatedPackages
      if version and not semver.validRange(version)
        invalidPackages = true
        grunt.log.error("Invalid range: #{version} (#{name})")

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata))
    not invalidPackages
