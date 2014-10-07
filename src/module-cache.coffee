Module = require 'module'
fs = require 'fs-plus'

nativeModules = process.binding('natives')

try
  resourcePath = JSON.parse(decodeURIComponent(location.search.substr(14)))?.resourcePath
catch error
  return

originalResolveFilename = Module._resolveFilename

# Precompute versions of all modules in node_modules
# Precompute the version each file is compatible

getCachedModulePath = (relativePath, parentModule) ->
  return unless relativePath
  return unless parentModule?.id

  return if nativeModules.hasOwnProperty(relativePath)
  return if relativePath[0] is '.'
  return if relativePath[relativePath.length - 1] is '/'
  return if fs.isAbsolute(relativePath)

  console.log "looking up #{relative} from #{parentModule.id}"

  undefined

Module._resolveFilename = (relativePath, parentModule) ->
  getCachedModulePath(relativePath, parentModule) ? originalResolveFilename(relativePath, parentModule)
