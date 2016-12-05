'use strict'

const assert = require('assert')
const downloadFileFromGithub = require('./download-file-from-github')
const fs = require('fs-extra')
const path = require('path')
const semver = require('semver')
const spawnSync = require('./spawn-sync')
const syncRequest = require('sync-request')

const CONFIG = require('../config')

module.exports = function () {
  // Chromedriver is only distributed with the first patch release for any given
  // major and minor version of electron.
  const electronVersion = semver.parse(CONFIG.appMetadata.electronVersion)
  const electronVersionWithChromedriver = `${electronVersion.major}.${electronVersion.minor}.0`
  const electronAssets = getElectronAssetsForVersion(electronVersionWithChromedriver)
  const chromeDriverMatch = new RegExp(`^chromedriver-v.*-${process.platform}-${process.arch}`)
  const chromedriverAssets = electronAssets.filter(e => chromeDriverMatch.test(e.name))
  assert(chromedriverAssets.length === 1, 'Found more than one chrome driver asset to download!')
  const chromedriverAsset = chromedriverAssets[0]

  const chromedriverZipPath = path.join(CONFIG.electronDownloadPath, `electron-${electronVersionWithChromedriver}-${chromedriverAsset.name}`)
  if (!fs.existsSync(chromedriverZipPath)) {
    downloadFileFromGithub(chromedriverAsset.url, chromedriverZipPath)
  }

  const chromedriverDirPath = path.join(CONFIG.electronDownloadPath, 'chromedriver')
  unzipPath(chromedriverZipPath, chromedriverDirPath)
}

function getElectronAssetsForVersion (version) {
  const releaseURL = `https://api.github.com/repos/electron/electron/releases/tags/v${version}`
  const response = syncRequest('GET', releaseURL, {'headers': {'User-Agent': 'Atom Build'}})

  if (response.statusCode === 200) {
    const release = JSON.parse(response.body)
    return release.assets.map(a => { return {name: a.name, url: a.browser_download_url} })
  } else {
    throw new Error(`Error getting assets for ${releaseURL}. HTTP Status ${response.statusCode}.`)
  }
}

function unzipPath (inputPath, outputPath) {
  if (fs.existsSync(outputPath)) {
    console.log(`Removing "${outputPath}"`)
    fs.removeSync(outputPath)
  }

  console.log(`Unzipping "${inputPath}" to "${outputPath}"`)
  try {
    spawnSync('unzip', [inputPath, '-d', outputPath])
  }
  catch(err) {
    if (err.code === 'ENOENT') {
      // Unzip might not be available on Windows even though it comes with git so fall back to 7zip
      spawnSync('7z', ['x', inputPath, `-o${outputPath}`])
    }
    else {
      throw err;
    }
  }
}
