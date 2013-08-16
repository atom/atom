require 'window'

measure 'spec suite require time', ->
  fs = require 'fs'
  fsUtils = require 'fs-utils'
  path = require 'path'
  _ = require 'underscore'
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

  fixturesPackagesPath = fsUtils.resolveOnLoadPath('fixtures/packages')
  packagePaths = atom.getAvailablePackageNames().map (packageName) -> atom.resolvePackagePath(packageName)
  packagePaths = _.groupBy packagePaths, (packagePath) ->
    if packagePath.indexOf("#{fixturesPackagesPath}#{path.sep}") is 0
      'fixtures'
    else if packagePath.indexOf("#{window.resourcePath}#{path.sep}") is 0
      'bundled'
    else
      'user'

  # Run bundled package specs
  requireSpecs(packagePath) for packagePath in packagePaths.bundled
  setSpecType('bundled')

  # Run user package specs
  requireSpecs(packagePath) for packagePath in packagePaths.user
  setSpecType('user')
