Module = require 'module'
path = require 'path'
fs = require 'fs-plus'
semver = require 'semver'

# Make sure CoffeeScript is required when this file is required directly
# by apm
unless require.extensions['.coffee']
  require('coffee-script').register()

nativeModules = process.binding('natives')

cache =
  debug: false
  dependencies: {}
  folders: {}
  ranges: {}
  registered: false

loadDependencies = (modulePath, rootPath, rootMetadata, moduleCache) ->
  for childPath in fs.listSync(path.join(modulePath, 'node_modules'))
    continue if path.basename(childPath) is '.bin'
    continue if rootPath is modulePath and rootMetadata.packageDependencies?.hasOwnProperty(path.basename(childPath))

    childMetadataPath = path.join(childPath, 'package.json')
    continue unless fs.isFileSync(childMetadataPath)

    childMetadata = JSON.parse(fs.readFileSync(childMetadataPath))
    if childMetadata?.version
      try
        mainPath = require.resolve(childPath)

      if mainPath
        moduleCache.dependencies.push
          name: childMetadata.name
          version: childMetadata.version
          path: path.relative(rootPath, mainPath)

      loadDependencies(childPath, rootPath, rootMetadata, moduleCache)

  undefined

loadFolderCompatibility = (modulePath, rootPath, rootMetadata, moduleCache) ->
  metadataPath = path.join(modulePath, 'package.json')
  return unless fs.isFileSync(metadataPath)

  dependencies = JSON.parse(fs.readFileSync(metadataPath))?.dependencies ? {}

  for name, version of dependencies
    try
      new semver.Range(version)
    catch error
      delete dependencies[name]
      console.log "Ignoring invalid range: #{name} #{version}"

  onDirectory = (childPath) ->
    path.basename(childPath) isnt 'node_modules'

  extensions = Object.keys(require.extensions)
  paths = {}
  onFile = (childPath) ->
    if path.extname(childPath) in extensions
      relativePath = path.relative(rootPath, path.dirname(childPath))
      paths[relativePath] = true
  fs.traverseTreeSync(modulePath, onFile, onDirectory)

  paths = Object.keys(paths)
  if paths.length > 0 and Object.keys(dependencies).length > 0
    moduleCache.folders.push({paths, dependencies})

  for childPath in fs.listSync(path.join(modulePath, 'node_modules'))
    continue if path.basename(childPath) is '.bin'
    continue if rootPath is modulePath and rootMetadata.packageDependencies?.hasOwnProperty(path.basename(childPath))

    loadFolderCompatibility(childPath, rootPath, rootMetadata, moduleCache)

  undefined

satisfies = (version, rawRange) ->
  unless parsedRange = cache.ranges[rawRange]
    parsedRange = new semver.Range(rawRange)
    cache.ranges[rawRange] = parsedRange
  parsedRange.test(version)

getCachedModulePath = (relativePath, parentModule) ->
  return unless relativePath
  return unless parentModule?.id

  return if nativeModules.hasOwnProperty(relativePath)
  return if relativePath[0] is '.'
  return if relativePath[relativePath.length - 1] is '/'
  return if fs.isAbsolute(relativePath)

  folderPath = path.dirname(parentModule.id)

  range = cache.folders[folderPath]?[relativePath]
  return unless range?

  candidates = cache.dependencies[relativePath]
  return unless candidates?

  for version, resolvedPath of candidates
    if Module._cache.hasOwnProperty(resolvedPath) and satisfies(version, range)
      return resolvedPath

  undefined

if cache.debug
  cache.loadCount = 0
  cache.requireTime = 0
  global.moduleCache = cache

  originalLoad = Module::load
  Module::load = ->
    cache.loadCount++
    originalLoad.apply(this, arguments)

  originalRequire = Module::require
  Module::require = ->
    startTime = Date.now()
    exports = originalRequire.apply(this, arguments)
    cache.requireTime += Date.now() - startTime
    exports

exports.create = (modulePath) ->
  modulePath = fs.realpathSync(modulePath)
  metadataPath = path.join(modulePath, 'package.json')
  metadata = JSON.parse(fs.readFileSync(metadataPath))

  moduleCache =
    version: 1
    dependencies: []
    folders: []

  loadDependencies(modulePath, modulePath, metadata, moduleCache)
  loadFolderCompatibility(modulePath, modulePath, metadata, moduleCache)

  metadata._atomModuleCache = moduleCache
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2))
  undefined

exports.register = ->
  return if cache.registered

  originalResolveFilename = Module._resolveFilename
  Module._resolveFilename = (relativePath, parentModule) ->
    resolvedPath = getCachedModulePath(relativePath, parentModule)
    resolvedPath ? originalResolveFilename(relativePath, parentModule)
  cache.registered = true

  undefined

exports.add = (directoryPath, metadata) ->
  unless metadata?
    try
      metadata = require(path.join(directoryPath, 'package.json'))
    catch error
      return

  cacheToAdd = metadata?._atomModuleCache
  for dependency in cacheToAdd?.dependencies ? []
    cache.dependencies[dependency.name] ?= {}
    cache.dependencies[dependency.name][dependency.version] ?= path.join(directoryPath, dependency.path)

  for entry in cacheToAdd?.folders ? []
    for folderPath in entry.paths
      cache.folders[path.join(directoryPath, folderPath)] = entry.dependencies

  undefined

exports.cache = cache
