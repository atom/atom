semver = require 'semver'
deprecatedPackages = null

exports.isDeprecatedPackage = (name, version) ->
  deprecatedPackages ?= require('../deprecated-packages') ? {}
  return false unless deprecatedPackages.hasOwnProperty(name)

  deprecatedVersionRange = deprecatedPackages[name].version
  return true unless deprecatedVersionRange

  semver.valid(version) and semver.validRange(deprecatedVersionRange) and semver.satisfies(version, deprecatedVersionRange)
