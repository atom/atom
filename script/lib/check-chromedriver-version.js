'use strict'

const buildMetadata = require('../package.json')
const CONFIG = require('../config')
const semver = require('semver')

module.exports = function () {
  // Chromedriver should be specified as ^n.x where n matches the Electron major version
  const chromedriverVer = buildMetadata.dependencies['electron-chromedriver']
  const mksnapshotVer = buildMetadata.dependencies['electron-mksnapshot']

  // Always use caret on electron-chromedriver so that it can pick up the best minor/patch versions
  if (!chromedriverVer.startsWith('^')) {
    throw new Error(`electron-chromedriver version in script/package.json should start with a caret to match latest patch version.`)
  }

  if (!mksnapshotVer.startsWith('^')) {
    throw new Error(`electron-mksnapshot version in script/package.json should start with a caret to match latest patch version.`)
  }

  const electronVer = CONFIG.appMetadata.electronVersion
  if (!semver.satisfies(electronVer, chromedriverVer)) {
    throw new Error(`electron-chromedriver ${chromedriverVer} incompatible with electron ${electronVer}.\n` +
                    'Did you upgrade electron in package.json and forget to upgrade electron-chromedriver in ' +
                    `script/package.json to '~${semver.major(electronVer)}.${semver.minor(electronVer)}' ?`)
  }

  if (!semver.satisfies(electronVer, mksnapshotVer)) {
    throw new Error(`electron-mksnapshot ${mksnapshotVer} incompatible with electron ${electronVer}.\n` +
                    'Did you upgrade electron in package.json and forget to upgrade electron-mksnapshot in ' +
                    `script/package.json to '~${semver.major(electronVer)}.${semver.minor(electronVer)}' ?`)
  }
}
