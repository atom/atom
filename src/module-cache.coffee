Module = require 'module'
path = require 'path'
semver = require 'semver'

# Extend semver.Range to memoize matched versions for speed
class Range extends semver.Range
  constructor: ->
    super
    @matchedVersions = new Set()
    @unmatchedVersions = new Set()

  test: (version) ->
    return true if @matchedVersions.has(version)
    return false if @unmatchedVersions.has(version)

    matches = super
    if matches
      @matchedVersions.add(version)
    else
      @unmatchedVersions.add(version)
    matches

nativeModules = process.binding('natives')

cache =
  builtins: {}
  debug: false
  dependencies: {}
  extensions: {}
  folders: {}
  ranges: {}
  registered: false
  resourcePath: null
  resourcePathWithTrailingSlash: null

# isAbsolute is inlined from fs-plus so that fs-plus itself can be required
# from this cache.
if process.platform is 'win32'
  isAbsolute = (pathToCheck) ->
    pathToCheck and (pathToCheck[1] is ':' or (pathToCheck[0] is '\\' and pathToCheck[1] is '\\'))
else
  isAbsolute = (pathToCheck) ->
    pathToCheck and pathToCheck[0] is '/'

isCorePath = (pathToCheck) ->
  pathToCheck.startsWith(cache.resourcePathWithTrailingSlash)

loadDependencies = (modulePath, rootPath, rootMetadata, moduleCache) ->
  fs = require 'fs-plus'

  for childPath in fs.listSync(path.join(modulePath, 'node_modules'))
    continue if path.basename(childPath) is '.bin'
    continue if rootPath is modulePath and rootMetadata.packageDependencies?.hasOwnProperty(path.basename(childPath))

    childMetadataPath = path.join(childPath, 'package.json')
    continue unless fs.isFileSync(childMetadataPath)

    childMetadata = JSON.parse(fs.readFileSync(childMetadataPath))
    if childMetadata?.version
      try
        mainPath = require.resolve(childPath)
      catch error
        mainPath = null

      if mainPath
        moduleCache.dependencies.push
          name: childMetadata.name
          version: childMetadata.version
          path: path.relative(rootPath, mainPath)

      loadDependencies(childPath, rootPath, rootMetadata, moduleCache)

  return

loadFolderCompatibility = (modulePath, rootPath, rootMetadata, moduleCache) ->
  fs = require 'fs-plus'

  metadataPath = path.join(modulePath, 'package.json')
  return unless fs.isFileSync(metadataPath)

  dependencies = JSON.parse(fs.readFileSync(metadataPath))?.dependencies ? {}

  for name, version of dependencies
    try
      new Range(version)
    catch error
      delete dependencies[name]

  onDirectory = (childPath) ->
    path.basename(childPath) isnt 'node_modules'

  extensions = ['.js', '.coffee', '.json', '.node']
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

  return

loadExtensions = (modulePath, rootPath, rootMetadata, moduleCache) ->
  fs = require 'fs-plus'
  extensions = ['.js', '.coffee', '.json', '.node']
  nodeModulesPath = path.join(rootPath, 'node_modules')

  onFile = (filePath) ->
    filePath = path.relative(rootPath, filePath)
    segments = filePath.split(path.sep)
    return if 'test' in segments
    return if 'tests' in segments
    return if 'spec' in segments
    return if 'specs' in segments
    return if segments.length > 1 and not (segments[0] in ['exports', 'lib', 'node_modules', 'src', 'static', 'vendor'])

    extension = path.extname(filePath)
    if extension in extensions
      moduleCache.extensions[extension] ?= []
      moduleCache.extensions[extension].push(filePath)

  onDirectory = (childPath) ->
    # Don't include extensions from bundled packages
    # These are generated and stored in the package's own metadata cache
    if rootMetadata.name is 'atom'
      parentPath = path.dirname(childPath)
      if parentPath is nodeModulesPath
        packageName = path.basename(childPath)
        return false if rootMetadata.packageDependencies?.hasOwnProperty(packageName)

    true

  fs.traverseTreeSync(rootPath, onFile, onDirectory)

  return

satisfies = (version, rawRange) ->
  unless parsedRange = cache.ranges[rawRange]
    parsedRange = new Range(rawRange)
    cache.ranges[rawRange] = parsedRange
  parsedRange.test(version)

resolveFilePath = (relativePath, parentModule) ->
  return unless relativePath
  return unless parentModule?.filename
  return unless relativePath[0] is '.' or isAbsolute(relativePath)

  resolvedPath = path.resolve(path.dirname(parentModule.filename), relativePath)
  return unless isCorePath(resolvedPath)

  extension = path.extname(resolvedPath)
  if extension
    return resolvedPath if cache.extensions[extension]?.has(resolvedPath)
  else
    for extension, paths of cache.extensions
      resolvedPathWithExtension = "#{resolvedPath}#{extension}"
      return resolvedPathWithExtension if paths.has(resolvedPathWithExtension)

  return

resolveModulePath = (relativePath, parentModule) ->
  return unless relativePath
  return unless parentModule?.filename

  return if nativeModules.hasOwnProperty(relativePath)
  return if relativePath[0] is '.'
  return if isAbsolute(relativePath)

  folderPath = path.dirname(parentModule.filename)

  range = cache.folders[folderPath]?[relativePath]
  unless range?
    if builtinPath = cache.builtins[relativePath]
      return builtinPath
    else
      return

  candidates = cache.dependencies[relativePath]
  return unless candidates?

  for version, resolvedPath of candidates
    if Module._cache.hasOwnProperty(resolvedPath) or isCorePath(resolvedPath)
      return resolvedPath if satisfies(version, range)

  return

registerBuiltins = (devMode) ->
  if devMode or not cache.resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")
    fs = require 'fs-plus'
    atomCoffeePath = path.join(cache.resourcePath, 'exports', 'atom.coffee')
    cache.builtins.atom = atomCoffeePath if fs.isFileSync(atomCoffeePath)
  cache.builtins.atom ?= path.join(cache.resourcePath, 'exports', 'atom.js')

  atomShellRoot = path.join(process.resourcesPath, 'atom.asar')

  commonRoot = path.join(atomShellRoot, 'common', 'api', 'lib')
  commonBuiltins = ['callbacks-registry', 'clipboard', 'crash-reporter', 'screen', 'shell']
  for builtin in commonBuiltins
    cache.builtins[builtin] = path.join(commonRoot, "#{builtin}.js")

  rendererRoot = path.join(atomShellRoot, 'renderer', 'api', 'lib')
  rendererBuiltins = ['ipc', 'remote']
  for builtin in rendererBuiltins
    cache.builtins[builtin] = path.join(rendererRoot, "#{builtin}.js")

if cache.debug
  cache.findPathCount = 0
  cache.findPathTime = 0
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

  originalFindPath = Module._findPath
  Module._findPath = (request, paths) ->
    cacheKey = JSON.stringify({request, paths})
    cache.findPathCount++ unless Module._pathCache[cacheKey]

    startTime = Date.now()
    foundPath = originalFindPath.apply(global, arguments)
    cache.findPathTime += Date.now() - startTime
    foundPath

exports.create = (modulePath) ->
  fs = require 'fs-plus'

  modulePath = fs.realpathSync(modulePath)
  metadataPath = path.join(modulePath, 'package.json')
  metadata = JSON.parse(fs.readFileSync(metadataPath))

  moduleCache =
    version: 1
    dependencies: []
    extensions: {}
    folders: []

  loadDependencies(modulePath, modulePath, metadata, moduleCache)
  loadFolderCompatibility(modulePath, modulePath, metadata, moduleCache)
  loadExtensions(modulePath, modulePath, metadata, moduleCache)

  metadata._atomModuleCache = moduleCache
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2))

  return

exports.register = ({resourcePath, devMode}={}) ->
  return if cache.registered

  originalResolveFilename = Module._resolveFilename
  Module._resolveFilename = (relativePath, parentModule) ->
    resolvedPath = resolveModulePath(relativePath, parentModule)
    resolvedPath ?= resolveFilePath(relativePath, parentModule)
    resolvedPath ? originalResolveFilename(relativePath, parentModule)

  cache.registered = true
  cache.resourcePath = resourcePath
  cache.resourcePathWithTrailingSlash = "#{resourcePath}#{path.sep}"
  registerBuiltins(devMode)

  return

exports.add = (directoryPath, metadata) ->
  # path.join isn't used in this function for speed since path.join calls
  # path.normalize and all the paths are already normalized here.

  unless metadata?
    try
      metadata = require("#{directoryPath}#{path.sep}package.json")
    catch error
      return

  cacheToAdd = metadata?._atomModuleCache
  return unless cacheToAdd?

  for dependency in cacheToAdd.dependencies ? []
    cache.dependencies[dependency.name] ?= {}
    cache.dependencies[dependency.name][dependency.version] ?= "#{directoryPath}#{path.sep}#{dependency.path}"

  for entry in cacheToAdd.folders ? []
    for folderPath in entry.paths
      if folderPath
        cache.folders["#{directoryPath}#{path.sep}#{folderPath}"] = entry.dependencies
      else
        cache.folders[directoryPath] = entry.dependencies

  for extension, paths of cacheToAdd.extensions
    cache.extensions[extension] ?= new Set()
    for filePath in paths
      cache.extensions[extension].add("#{directoryPath}#{path.sep}#{filePath}")

  return

exports.cache = cache
