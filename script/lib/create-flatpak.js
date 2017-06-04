'use strict'

const childProcess = require('child_process')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')
const template = require('lodash.template')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  console.log(`Creating flatpak package for "${packagedAppPath}"`)
  const atomExecutableName = 'atom'
  const apmExecutableName = 'apm'
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  const appId = 'io.atom.Atom'
  const baseAppId = 'io.atom.electron.BaseApp'
  const baseAppVersion = 'master'
  // FIXME: This should be update to wherever the electron base app is eventually hosted!
  const baseAppFlatpakref = 'FIXME'
  const appDescription = CONFIG.appMetadata.description
  const appVersion = CONFIG.appMetadata.version
  let arch
  if (process.arch === 'ia32') {
    arch = 'i386'
  } else if (process.arch === 'x64') {
    arch = 'x86_64'
  } else {
    arch = process.arch
  }

  const outputFlatpakFilePath = path.join(CONFIG.buildOutputPath, `atom-${arch}.flatpak`)
  const flatpakWorkingDirPath = path.join(path.sep, 'var', 'tmp', path.basename(packagedAppPath))
  const flatpakManifestPath = path.join(flatpakWorkingDirPath, 'manifest.json')
  const flatpakBuildDirPath = path.join(flatpakWorkingDirPath, 'build')
  const flatpakRepoDirPath = path.join(flatpakWorkingDirPath, 'repo')
  const flatpakInstallDirPath = path.join(flatpakBuildDirPath, 'files')
  const flatpakBinDirPath = path.join(flatpakInstallDirPath, 'bin')
  const flatpakShareDirPath = path.join(flatpakInstallDirPath, 'share')
  const flatpakAtomDirPath = path.join(flatpakShareDirPath, atomExecutableName)
  const flatpakApplicationsDirPath = path.join(flatpakShareDirPath, 'applications')
  const flatpakIconsDirPath = path.join(flatpakShareDirPath, 'pixmaps')
  const flatpakExportIconDirPath = path.join(flatpakBuildDirPath, 'export', 'share', 'pixmaps')
  const flatpakDocsDirPath = path.join(flatpakShareDirPath, 'doc', atomExecutableName)

  if (fs.existsSync(flatpakWorkingDirPath)) {
    console.log(`Deleting existing build dir for flatpak package at "${flatpakWorkingDirPath}"`)
    fs.removeSync(flatpakWorkingDirPath)
  }

  if (fs.existsSync(outputFlatpakFilePath)) {
    console.log(`Deleting existing flatpak package at "${outputFlatpakFilePath}"`)
    fs.removeSync(outputFlatpakFilePath)
  }

  console.log(`Creating flatpak manifest files at "${flatpakManifestPath}"`)
  fs.mkdirpSync(flatpakWorkingDirPath)
  const manifestFileTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'flatpak', 'manifest.json.in'))
  const manifestFileContents = template(manifestFileTemplate)({
    appId: appId,
    baseAppId: baseAppId,
    baseAppVersion: baseAppVersion,
    channel: CONFIG.channel,
    atomExecutableName: atomExecutableName
  })
  fs.writeFileSync(flatpakManifestPath, manifestFileContents)

  console.log(`Checking for base electron application...`)
  const checkInstallArgs = ['info', '--show-commit', baseAppId, baseAppVersion]
  // Use childProcess.spawnSync because we want the status code for these commands.
  const checkUserResult = childProcess.spawnSync('flatpak', ['--user'].concat(checkInstallArgs))
  const checkSystemResult = childProcess.spawnSync('flatpak', ['--system'].concat(checkInstallArgs))
  const hasUserInstall = checkUserResult.status === 0
  const hasSystemInstall = checkSystemResult.status === 0
  if (!hasUserInstall && !hasSystemInstall) {
    console.log(`Base electron application not found. Installing...`)
    spawnSync('flatpak', ['install', '--user', '--from', baseAppFlatpakref], {stdio: 'inherit'})
  } else {
    console.log(`Base electron application found. Checking for updates...`)
    const updateArgs = ['update', baseAppId, baseAppVersion];
    if (hasUserInstall) updateArgs.unshift('--user')
    spawnSync('flatpak', updateArgs, {stdio: 'inherit'})
  }

  console.log(`Initializing flatpak build at "${flatpakBuildDirPath}"`)
  const flatpakBuilderArgs = [`--arch=${arch}`, `--allow-missing-runtimes`, flatpakBuildDirPath, flatpakManifestPath]
  spawnSync('flatpak-builder', ['--build-only'].concat(flatpakBuilderArgs), {stdio: 'inherit'})

  console.log(`Initializing flatpak directory structure at "${flatpakInstallDirPath}"`)
  fs.mkdirpSync(flatpakShareDirPath)
  fs.mkdirpSync(flatpakApplicationsDirPath)
  fs.mkdirpSync(flatpakIconsDirPath)
  fs.mkdirpSync(flatpakDocsDirPath)
  fs.mkdirpSync(flatpakBinDirPath)

  console.log(`Copying "${packagedAppPath}" to "${flatpakAtomDirPath}"`)
  fs.copySync(packagedAppPath, flatpakAtomDirPath)
  fs.chmodSync(flatpakAtomDirPath, '755')

  console.log(`Copying binaries into "${flatpakBinDirPath}"`)
  fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(flatpakBinDirPath, atomExecutableName))
  fs.symlinkSync(
    path.join('..', 'share', atomExecutableName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'),
    path.join(flatpakBinDirPath, apmExecutableName)
  )

  console.log(`Writing desktop entry file into "${flatpakApplicationsDirPath}"`)
  const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: appName, appFileName: atomExecutableName, description: appDescription,
    installDir: '/app', iconPath: appId
  })
  fs.writeFileSync(path.join(flatpakApplicationsDirPath, `${appId}.desktop`), desktopEntryContents)

  console.log(`Copying icon into "${flatpakIconsDirPath}"`)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'app.asar.unpacked', 'resources', 'atom.png'),
    path.join(flatpakIconsDirPath, `${appId}.png`)
  )

  console.log(`Copying license into "${flatpakDocsDirPath}"`)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'LICENSE.md'),
    path.join(flatpakDocsDirPath, 'copyright')
  )

  console.log(`Finalizing flatpak build at ${flatpakBuildDirPath}`)
  spawnSync('flatpak-builder', ['--finish-only'].concat(flatpakBuilderArgs), {stdio: 'inherit'})

  console.log(`Creating special export for pixmap "${outputFlatpakFilePath}"`)
  fs.mkdirpSync(flatpakExportIconDirPath)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'app.asar.unpacked', 'resources', 'atom.png'),
    path.join(flatpakExportIconDirPath, `${appId}.png`)
  )

  console.log(`Exporting flatpak at ${flatpakBuildDirPath}`)
  spawnSync('flatpak', ['build-export', `--arch=${arch}`, flatpakRepoDirPath, flatpakBuildDirPath, CONFIG.channel], {stdio: 'inherit'})

  console.log(`Creating single file bundle in "${outputFlatpakFilePath}"`)
  spawnSync('flatpak', ['build-bundle', `--arch=${arch}`, flatpakRepoDirPath, outputFlatpakFilePath, appId, CONFIG.channel], {stdio: 'inherit'})
}
