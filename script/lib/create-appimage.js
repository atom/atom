'use strict'

const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')
const template = require('lodash.template')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  console.log(`Creating AppImage package for "${packagedAppPath}"`)
  const atomExecutableName = CONFIG.channel === 'beta' ? 'atom-beta' : 'atom'
  const apmExecutableName = CONFIG.channel === 'beta' ? 'apm-beta' : 'apm'
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  const appDescription = CONFIG.appMetadata.description
  const appVersion = CONFIG.appMetadata.version
  let arch
  if (process.arch === 'ia32') {
    arch = 'i386'
  } else if (process.arch === 'x64') {
    arch = 'amd64'
  } else if (process.arch === 'ppc') {
    arch = 'powerpc'
  } else {
    arch = process.arch
  }

  const outputAppImagePackageFilePath = path.join(CONFIG.buildOutputPath, `atom-${arch}.AppImage`)
  const appimagePackageDirPath = path.join(os.tmpdir(), path.basename(packagedAppPath))
  const appimagePackageConfigPath = path.join(appimagePackageDirPath, 'APPIMAGE')
  const appimagePackageInstallDirPath = path.join(appimagePackageDirPath, 'usr')
  const appimagePackageBinDirPath = path.join(appimagePackageInstallDirPath, 'bin')
  const appimagePackageShareDirPath = path.join(appimagePackageInstallDirPath, 'share')
  const appimagePackageAtomDirPath = path.join(appimagePackageShareDirPath, atomExecutableName)
  const appimagePackageApplicationsDirPath = path.join(appimagePackageShareDirPath, 'applications')
  const appimagePackageIconsDirPath = path.join(appimagePackageShareDirPath, 'pixmaps')
  const appimagePackageDocsDirPath = path.join(appimagePackageShareDirPath, 'doc', atomExecutableName)

  if (fs.existsSync(appimagePackageDirPath)) {
    console.log(`Deleting existing build dir for AppImage package at "${appimagePackageDirPath}"`)
    fs.removeSync(appimagePackageDirPath)
  }
  if (fs.existsSync(`${appimagePackageDirPath}.AppImage`)) {
    console.log(`Deleting existing AppImage package at "${appimagePackageDirPath}.AppImage"`)
    fs.removeSync(`${appimagePackageDirPath}.AppImage`)
  }
  if (fs.existsSync(appimagePackageDirPath)) {
    console.log(`Deleting existing AppImage package at "${outputAppImagePackageFilePath}"`)
    fs.removeSync(appimagePackageDirPath)
  }

  console.log(`Creating AppImage package directory structure at "${appimagePackageDirPath}"`)
  fs.mkdirpSync(appimagePackageDirPath)
  fs.mkdirpSync(appimagePackageConfigPath)
  fs.mkdirpSync(appimagePackageInstallDirPath)
  fs.mkdirpSync(appimagePackageShareDirPath)
  fs.mkdirpSync(appimagePackageApplicationsDirPath)
  fs.mkdirpSync(appimagePackageIconsDirPath)
  fs.mkdirpSync(appimagePackageDocsDirPath)
  fs.mkdirpSync(appimagePackageBinDirPath)

  console.log(`Copying "${packagedAppPath}" to "${appimagePackageAtomDirPath}"`)
  fs.copySync(packagedAppPath, appimagePackageAtomDirPath)
  fs.chmodSync(appimagePackageAtomDirPath, '755')

  console.log(`Copying binaries into "${appimagePackageBinDirPath}"`)
  fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(appimagePackageBinDirPath, atomExecutableName))
  fs.symlinkSync(
    path.join('..', 'share', atomExecutableName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'),
    path.join(appimagePackageBinDirPath, apmExecutableName)
  )

  console.log(`Writing control file into "${appimagePackageConfigPath}"`)
  const packageSizeInKilobytes = spawnSync('du', ['-sk', packagedAppPath]).stdout.toString().split(/\s+/)[0]
  const controlFileTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'appimage', 'control.in'))
  const controlFileContents = template(controlFileTemplate)({
    appFileName: atomExecutableName, version: appVersion, arch: arch,
    installedSize: packageSizeInKilobytes, description: appDescription
  })
  fs.writeFileSync(path.join(appimagePackageConfigPath, 'control'), controlFileContents)

  console.log(`Writing desktop entry file into "${appimagePackageApplicationsDirPath}"`)
  const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: appName, appFileName: atomExecutableName, description: appDescription,
    installDir: '/usr', iconPath: atomExecutableName
  })
  fs.writeFileSync(path.join(appimagePackageApplicationsDirPath, `${atomExecutableName}.desktop`), desktopEntryContents)

  console.log(`Copying icon into "${appimagePackageIconsDirPath}"`)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'app.asar.unpacked', 'resources', 'atom.png'),
    path.join(appimagePackageIconsDirPath, `${atomExecutableName}.png`)
  )

  console.log(`Copying license into "${appimagePackageDocsDirPath}"`)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'LICENSE.md'),
    path.join(appimagePackageDocsDirPath, 'copyright')
  )

  console.log(`Generating .AppImage file from ${appimagePackageDirPath}`)
  spawnSync('wget', ["-c", "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"], {stdio: 'inherit'})
  spawnSync('chmod', ["+x", "appimagetool-*.AppImage"], {stdio: 'inherit'})
  spawnSync('appimagetool', [appimagePackageDirPath, outputAppImagePackageFilePath], {stdio: 'inherit'})
}
