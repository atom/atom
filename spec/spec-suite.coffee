require 'window'

measure 'spec suite require time', ->
  fsUtils = require 'fs-utils'
  path = require 'path'
  require 'spec-helper'

  requireSpecs = (directoryPath, specType) ->
    for specPath in fsUtils.listTreeSync(path.join(directoryPath, 'spec')) when /-spec\.coffee$/.test specPath
      require specPath
    for spec in jasmine.getEnv().currentRunner().specs() when not spec.specType?
      spec.specType = specType

  # Run core specs
  requireSpecs(window.resourcePath, 'core')

  # Run internal package specs
  for packagePath in fsUtils.listTreeSync(config.bundledPackagesDirPath)
    requireSpecs(packagePath, 'internal')

  # Run bundled package specs
  for packagePath in fsUtils.listTreeSync(config.nodeModulesDirPath) when atom.isInternalPackage(packagePath)
    requireSpecs(packagePath, 'bundled')

  # Run user package specs
  for packagePath in fsUtils.listTreeSync(config.userPackagesDirPath)
    requireSpecs(packagePath, 'user')
