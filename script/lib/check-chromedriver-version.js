'use strict'

const buildMetadata = require('../package.json')
const CONFIG = require('../config')
const semver = require('semver')

module.exports = function () {
  // Chromedriver should be specified as ~x.y where x and y match Electron major/minor
  const chromedriverVer = buildMetadata.dependencies['electron-chromedriver']

  // Always use tilde on electron-chromedriver so that it can pick up the best patch vesion
  if (!chromedriverVer.startsWith('~')) {
    throw new Error(`electron-chromedriver version in script/package.json should start with a tilde to match latest patch version.`)
  }

  const electronVer = CONFIG.appMetadata.electronVersion
  if (!semver.satisfies(electronVer, chromedriverVer)) {
    throw new Error(`electron-chromedriver ${chromedriverVer} incompatible with electron ${electronVer}.\n` +
                    'Did you upgrade electron in package.json and forget to upgrade electron-chromedriver in ' +
                    `script/package.json to '~${semver.major(electronVer)}.${semver.minor(electronVer)}' ?`)
  }
}
