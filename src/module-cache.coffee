Module = require 'module'
path = require 'path'
fs = require 'fs-plus'

nativeModules = process.binding('natives')

originalResolveFilename = Module._resolveFilename

loadDependencies = (modulePath, rootPath, rootMetadata, moduleCache) ->
  nodeModulesPath = path.join(modulePath, 'node_modules')
  for childPath in fs.listSync(nodeModulesPath)
    continue if path.basename(childPath) is '.bin'
    continue if rootPath is modulePath and rootMetadata.packageDependencies?.hasOwnProperty(path.basename(childPath))

    childMetadataPath = path.join(childPath, 'package.json')
    continue unless fs.isFileSync(childMetadataPath)

    childMetadata = JSON.parse(fs.readFileSync(childMetadataPath))
    if childMetadata?.version
      relativePath = path.relative(rootPath, childPath)
      moduleCache.dependencies[relativePath] = childMetadata.version
      loadDependencies(childPath, rootPath, rootMetadata, moduleCache)

loadFolderCompatibility = (modulePath, rootPath, rootMetadata, moduleCache) ->
  metadataPath = path.join(modulePath, 'package.json')
  return unless fs.isFileSync(metadataPath)

  nodeModulesPath = path.join(modulePath, 'node_modules')
  dependencies = JSON.parse(fs.readFileSync(metadataPath))?.dependencies ? {}

  onDirectory = (childPath) ->
    path.basename(childPath) isnt 'node_modules'

  extensions = Object.keys(require.extensions)
  paths = {}
  onFile = (childPath) ->
    if path.extname(childPath) in extensions
      relativePath = path.relative(rootPath, path.dirname(childPath))
      paths[relativePath] = true
  fs.traverseTreeSync(modulePath, onFile, onDirectory)

  moduleCache.folders ?= []
  paths = Object.keys(paths)
  if paths.length > 0 and Object.keys(dependencies).length > 0
    moduleCache.folders.push({paths, dependencies})

  for childPath in fs.listSync(nodeModulesPath)
    continue if path.basename(childPath) is '.bin'
    continue if rootPath is modulePath and rootMetadata.packageDependencies?.hasOwnProperty(path.basename(childPath))

    loadFolderCompatibility(childPath, rootPath, rootMetadata, moduleCache)

# Precompute versions of all modules in node_modules
# Precompute the version each file is compatible
exports.generateDependencies = (modulePath) ->
  metadataPath = path.join(modulePath, 'package.json')
  metadata = JSON.parse(fs.readFileSync(metadataPath))

  moduleCache =
    version: 1
    dependencies: {}
  loadDependencies(modulePath, modulePath, metadata, moduleCache)
  loadFolderCompatibility(modulePath, modulePath, metadata, moduleCache)

  metadata._atomModuleCache = moduleCache
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2))

getCachedModulePath = (relativePath, parentModule) ->
  return unless relativePath
  return unless parentModule?.id

  return if nativeModules.hasOwnProperty(relativePath)
  return if relativePath[0] is '.'
  return if relativePath[relativePath.length - 1] is '/'
  return if fs.isAbsolute(relativePath)

  console.log "looking up #{relative} from #{parentModule.id}"

  undefined

registered = false
exports.register = ->
  return if registered

  Module._resolveFilename = (relativePath, parentModule) ->
    resolvedPath = getCachedModulePath(relativePath, parentModule)
    resolvedPath ? originalResolveFilename(relativePath, parentModule)
  registered = true
