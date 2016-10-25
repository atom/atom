/** @babel */

import semver from 'semver'
import {deprecatedPackages} from '../package.json'

const deprecatedPackages = deprecatedPackages || {}
const ranges = {}

// Extend semver.Range to memoize matched versions for speed
class Range extends semver.Range {
  constructor () {
    super(...arguments)
    this.matchedVersions = new Set()
    this.unmatchedVersions = new Set()
  }

  test (version) {
    if (this.matchedVersions.has(version)) return true
    if (this.unmatchedVersions.has(version)) return false

    const matches = super.test(...arguments)
    if (matches) {
      this.matchedVersions.add(version)
    } else {
      this.unmatchedVersions.add(version)
    }
    return matches
  }
}

function satisfies (version, rawRange) {
  let parsedRange = ranges[rawRange]
  if (!parsedRange) {
    parsedRange = new Range(rawRange)
    ranges[rawRange] = parsedRange
  }
  return parsedRange.test(version)
}

export function getDeprecatedPackageMetadata (name) {
  let metadata = null
  if (deprecatedPackages.hasOwnProperty(name)) {
    metadata = deprecatedPackages[name]
  }
  if (metadata) Object.freeze(metadata)
  return metadata
}

export function isDeprecatedPackage (name, version) {
  if (!deprecatedPackages.hasOwnProperty(name)) return false

  const deprecatedVersionRange = deprecatedPackages[name].version
  if (!deprecatedVersionRange) return true

  return semver.valid(version) && satisfies(version, deprecatedVersionRange)
}
