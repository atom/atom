measure 'spec suite require time', ->
  {_, fs} = require 'atom-api'
  path = require 'path'
  Git = require '../src/git'
  require './spec-helper'

  requireSpecs = (specDirectory, specType) ->
    for specFilePath in fs.listTreeSync(specDirectory) when /-spec\.coffee$/.test specFilePath
      require specFilePath

  setSpecType = (specType) ->
    for spec in jasmine.getEnv().currentRunner().specs() when not spec.specType?
      spec.specType = specType

  runAllSpecs = ->
    # Only run core specs when resource path is the Atom repository
    if Git.exists(window.resourcePath)
      requireSpecs(path.join(window.resourcePath, 'spec'))
      setSpecType('core')

    fixturesPackagesPath = fs.resolveOnLoadPath('fixtures/packages')
    packagePaths = atom.getAvailablePackageNames().map (packageName) -> atom.resolvePackagePath(packageName)
    packagePaths = _.groupBy packagePaths, (packagePath) ->
      if packagePath.indexOf("#{fixturesPackagesPath}#{path.sep}") is 0
        'fixtures'
      else if packagePath.indexOf("#{window.resourcePath}#{path.sep}") is 0
        'bundled'
      else
        'user'

    # Run bundled package specs
    requireSpecs(path.join(packagePath, 'spec')) for packagePath in packagePaths.bundled ? []
    setSpecType('bundled')

    # Run user package specs
    requireSpecs(path.join(packagePath, 'spec')) for packagePath in packagePaths.user ? []
    setSpecType('user')

  if specDirectory = atom.getLoadSettings().specDirectory
    requireSpecs(specDirectory)
    setSpecType('user')
  else
    runAllSpecs()
