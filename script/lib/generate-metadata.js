'use strict'

const CSON = require('season')
const deprecatedPackagesMetadata = require('../deprecated-packages')
const fs = require('fs-plus')
const normalizePackageData = require('normalize-package-data')
const path = require('path')
const semver = require('semver')
const spawnSync = require('./spawn-sync')

const CONFIG = require('../config')

module.exports = function () {
  console.log(`Generating metadata for ${path.join(CONFIG.intermediateAppPath, 'package.json')}`)
  CONFIG.appMetadata._atomPackages = buildBundledPackagesMetadata()
  CONFIG.appMetadata._atomMenu = buildPlatformMenuMetadata()
  CONFIG.appMetadata._atomKeymaps = buildPlatformKeymapsMetadata()
  CONFIG.appMetadata._deprecatedPackages = deprecatedPackagesMetadata
  CONFIG.appMetadata.version = computeAppVersion()
  checkDeprecatedPackagesMetadata()
  fs.writeFileSync(path.join(CONFIG.intermediateAppPath, 'package.json'), JSON.stringify(CONFIG.appMetadata))
}

function buildBundledPackagesMetadata () {
  const packages = {}
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    const packagePath = path.join(CONFIG.intermediateAppPath, 'node_modules', packageName)
    const packageMetadataPath = path.join(packagePath, 'package.json')
    const packageMetadata = JSON.parse(fs.readFileSync(packageMetadataPath, 'utf8'))
    normalizePackageData(packageMetadata, (msg) => {
      console.warn(`Invalid package metadata. ${packageMetadata.name}: ${msg}`)
    }, true)
    if (packageMetadata.repository && packageMetadata.repository.url && packageMetadata.repository.type === 'git') {
      packageMetadata.repository.url = packageMetadata.repository.url.replace(/^git\+/, '')
    }

    delete packageMetadata['_from']
    delete packageMetadata['_id']
    delete packageMetadata['dist']
    delete packageMetadata['readme']
    delete packageMetadata['readmeFilename']

    const packageModuleCache = packageMetadata._atomModuleCache || {}
    if (packageModuleCache.extensions && packageModuleCache.extensions['.json']) {
      const index = packageModuleCache.extensions['.json'].indexOf('package.json')
      if (index !== -1) {
        packageModuleCache.extensions['.json'].splice(index, 1)
      }
    }

    const packageNewMetadata = {metadata: packageMetadata, keymaps: {}, menus: {}}
    if (packageMetadata.main) {
      const mainPath = require.resolve(path.resolve(packagePath, packageMetadata.main))
      packageNewMetadata.main = path.relative(CONFIG.intermediateAppPath, mainPath)
    }

    const packageKeymapsPath = path.join(packagePath, 'keymaps')
    if (fs.existsSync(packageKeymapsPath)) {
      for (let packageKeymapName of fs.readdirSync(packageKeymapsPath)) {
        const packageKeymapPath = path.join(packageKeymapsPath, packageKeymapName)
        if (packageKeymapPath.endsWith('.cson') || packageKeymapPath.endsWith('.json')) {
          const relativePath = path.relative(CONFIG.intermediateAppPath, packageKeymapPath)
          packageNewMetadata.keymaps[relativePath] = CSON.readFileSync(packageKeymapPath)
        }
      }
    }

    const packageMenusPath = path.join(packagePath, 'menus')
    if (fs.existsSync(packageMenusPath)) {
      for (let packageMenuName of fs.readdirSync(packageMenusPath)) {
        const packageMenuPath = path.join(packageMenusPath, packageMenuName)
        if (packageMenuPath.endsWith('.cson') || packageMenuPath.endsWith('.json')) {
          const relativePath = path.relative(CONFIG.intermediateAppPath, packageMenuPath)
          packageNewMetadata.menus[relativePath] = CSON.readFileSync(packageMenuPath)
        }
      }
    }

    const packageStyleSheetsPath = path.join(packagePath, 'styles')
    let styleSheets = null
    if (packageMetadata.mainStyleSheet) {
      styleSheets = [fs.resolve(packagePath, packageMetadata.mainStyleSheet)]
    } else if (packageMetadata.styleSheets) {
      styleSheets = packageMetadata.styleSheets.map((name) => (
        fs.resolve(packageStyleSheetsPath, name, ['css', 'less', ''])
      ))
    } else {
      const indexStylesheet = fs.resolve(packagePath, 'index', ['css', 'less'])
      if (indexStylesheet) {
        styleSheets = [indexStylesheet]
      } else {
        styleSheets = fs.listSync(packageStyleSheetsPath, ['css', 'less'])
      }
    }

    packageNewMetadata.styleSheetsPaths =
      styleSheets.map(styleSheetPath => path.relative(packagePath, styleSheetPath))

    packages[packageMetadata.name] = packageNewMetadata
    if (packageModuleCache.extensions) {
      for (let extension of Object.keys(packageModuleCache.extensions)) {
        const paths = packageModuleCache.extensions[extension]
        if (paths.length === 0) {
          delete packageModuleCache.extensions[extension]
        }
      }
    }
  }
  return packages
}

function buildPlatformMenuMetadata () {
  const menuPath = path.join(CONFIG.repositoryRootPath, 'menus', `${process.platform}.cson`)
  if (fs.existsSync(menuPath)) {
    return CSON.readFileSync(menuPath)
  } else {
    return null
  }
}

function buildPlatformKeymapsMetadata () {
  const invalidPlatforms = ['darwin', 'freebsd', 'linux', 'sunos', 'win32'].filter(p => p !== process.platform)
  const keymapsPath = path.join(CONFIG.repositoryRootPath, 'keymaps')
  const keymaps = {}
  for (let keymapName of fs.readdirSync(keymapsPath)) {
    const keymapPath = path.join(keymapsPath, keymapName)
    if (keymapPath.endsWith('.cson') || keymapPath.endsWith('.json')) {
      const keymapPlatform = path.basename(keymapPath, path.extname(keymapPath))
      if (invalidPlatforms.indexOf(keymapPlatform) === -1) {
        keymaps[path.basename(keymapPath)] = CSON.readFileSync(keymapPath)
      }
    }
  }
  return keymaps
}

function checkDeprecatedPackagesMetadata () {
  for (let packageName of Object.keys(deprecatedPackagesMetadata)) {
    const packageMetadata = deprecatedPackagesMetadata[packageName]
    if (packageMetadata.version && !semver.validRange(packageMetadata.version)) {
      throw new Error(`Invalid range: ${version} (${name}).`)
    }
  }
}

function computeAppVersion () {
  let version = CONFIG.appMetadata.version
  if (CONFIG.channel === 'dev') {
    const result = spawnSync('git', ['rev-parse', '--short', 'HEAD'], {cwd: CONFIG.repositoryRootPath})
    const commitHash = result.stdout.toString().trim()
    version += '-' + commitHash
  }
  return version
}
