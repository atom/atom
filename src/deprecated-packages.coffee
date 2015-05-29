semver = require 'semver'

deprecatedPackages = require('../package.json')?._deprecatedPackages ? {}
ranges = {}

exports.isDeprecatedPackage = (name, version) ->
  return false unless deprecatedPackages.hasOwnProperty(name)
  return false unless semver.valid(version)

  deprecatedVersionRange = deprecatedPackages[name].version
  return true unless deprecatedVersionRange
  satisfies(version, deprecatedVersionRange)

satisfies = (version, rawRange) ->
  unless parsedRange = ranges[rawRange]
    parsedRange = new Range(rawRange)
    ranges[rawRange] = parsedRange
  parsedRange.test(version)

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
