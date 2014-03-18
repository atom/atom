_ = require 'underscore-plus'
fs = require 'fs-plus'
{Git} = require 'atom'
path = require 'path'
require './spec-helper'

requireSpecs = (specDirectory, specType) ->
  for specFilePath in fs.listTreeSync(specDirectory) when /-spec\.(coffee|js)$/.test specFilePath
    require specFilePath

    # Set spec directory on spec for setting up the project in spec-helper
    setSpecDirectory(specDirectory)

setSpecField = (name, value) ->
  specs = jasmine.getEnv().currentRunner().specs()
  return if specs.length is 0
  for index in [specs.length-1..0]
    break if specs[index][name]?
    specs[index][name] = value

setSpecType = (specType) ->
  setSpecField('specType', specType)

setSpecDirectory = (specDirectory) ->
  setSpecField('specDirectory', specDirectory)

runAllSpecs = ->
  {resourcePath} = atom.getLoadSettings()

  # Add 'src/exports' to module search path.
  exportsPath = path.resolve(resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  # Still set NODE_PATH since tasks may need it.
  process.env.NODE_PATH = exportsPath

  # Only run core specs when resource path is the Atom repository
  if Git.exists(resourcePath)
    requireSpecs(path.join(resourcePath, 'spec'))
    setSpecType('core')

  fixturesPackagesPath = path.join(__dirname, 'fixtures', 'packages')
  packagePaths = atom.packages.getAvailablePackageNames().map (packageName) ->
    atom.packages.resolvePackagePath(packageName)
  packagePaths = _.groupBy packagePaths, (packagePath) ->
    if packagePath.indexOf("#{fixturesPackagesPath}#{path.sep}") is 0
      'fixtures'
    else if packagePath.indexOf("#{resourcePath}#{path.sep}") is 0
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
