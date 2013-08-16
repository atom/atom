fs = require 'fs'

require 'window'

measure 'spec suite require time', ->
  fsUtils = require 'fs-utils'
  path = require 'path'
  require 'spec-helper'

  requireSpecs = (directoryPath, specType) ->
    for specPath in fsUtils.listTreeSync(path.join(directoryPath, 'spec')) when /-spec\.coffee$/.test specPath
      require specPath

  setSpecType = (specType) ->
    for spec in jasmine.getEnv().currentRunner().specs() when not spec.specType?
      spec.specType = specType

  # Run core specs
  requireSpecs(window.resourcePath)
  setSpecType('core')

  # Run bundled package specs
  if fsUtils.isDirectorySync(config.nodeModulesDirPath)
    for packageName in fs.readdirSync(config.nodeModulesDirPath)
      packagePath = path.join(config.nodeModulesDirPath, packageName)
      requireSpecs(packagePath, 'bundled') if atom.isInternalPackage(packagePath)
    setSpecType('bundled')

  # Run user package specs
  for packageDirPath in config.userPackageDirPaths when fsUtils.isDirectorySync(packageDirPath)
    for packageName in fs.readdirSync(packageDirPath)
      requireSpecs(path.join(packageDirPath, packageName))
    setSpecType('user')
