'use strict'

const childProcess = require('child_process')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')
const template = require('lodash.template')

const CONFIG = require('../config')

function ensureRef (id, arch, version, refPath) {
  console.log(`Checking for ${id}...`)
  const ref = [id, arch, version].join('/')
  const checkInstallArgs = ['info', '--show-commit', ref]
  // Use childProcess.spawnSync because we want the status code for these commands.
  const checkUserResult = childProcess.spawnSync('flatpak', ['--user'].concat(checkInstallArgs))
  const checkSystemResult = childProcess.spawnSync('flatpak', ['--system'].concat(checkInstallArgs))
  const hasUserInstall = checkUserResult.status === 0
  const hasSystemInstall = checkSystemResult.status === 0
  if (!hasUserInstall && !hasSystemInstall) {
    console.log(`${id} not found. Installing...`)
    spawnSync('flatpak', ['install', '--user', '--arch', arch, '--from', refPath], {stdio: 'inherit'})
  } else {
    console.log(`${id} found. Checking for updates...`)
    const updateArgs = ['update', id, version]
    if (hasUserInstall) updateArgs.unshift('--user')
    spawnSync('flatpak', updateArgs, {stdio: 'inherit'})
  }
}

module.exports = function (packagedAppPath) {
  console.log(`Creating flatpak package for "${packagedAppPath}"`)
  const atomExecutableName = 'atom'
  const apmExecutableName = 'apm'
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  const appId = 'io.atom.Atom'
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

  const runtimeId = 'org.freedesktop.Platform'
  const runtimeVersion = '1.4'
  const sdkId = 'org.freedesktop.Sdk'
  const baseAppId = 'io.atom.electron.BaseApp'
  const baseAppVersion = 'master'

  // Input paths
  const linuxResourceDirPath = path.join(CONFIG.repositoryRootPath, 'resources', 'linux')
  const desktopTemplatePath = path.join(linuxResourceDirPath, 'atom.desktop.in')
  const flatpakResourceDirPath = path.join(linuxResourceDirPath, 'flatpak')
  const manifestTemplatePath = path.join(flatpakResourceDirPath, 'manifest.json.in')
  const runtimeFlatpakrefPath = path.join(flatpakResourceDirPath, 'freedesktop-platform-1.4.flatpakref')
  const sdkFlatpakrefPath = path.join(flatpakResourceDirPath, 'freedesktop-sdk-1.4.flatpakref')
  const baseAppFlatpakrefPath = path.join(flatpakResourceDirPath, 'electron-base-app-master.flatpakref')

  // Output paths
  const outputFlatpakFilePath = path.join(CONFIG.buildOutputPath, `atom-${arch}.flatpak`)
  // We need to use /var/tmp instead of /tmp so flatpak can use xattrs
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

  ensureRef(runtimeId, arch, runtimeVersion, runtimeFlatpakrefPath)
  ensureRef(sdkId, arch, runtimeVersion, sdkFlatpakrefPath)
  ensureRef(baseAppId, arch, baseAppVersion, baseAppFlatpakrefPath)

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
  const manifestTemplate = fs.readFileSync(manifestTemplatePath)
  const manifestContents = template(manifestTemplate)({
    appId: appId,
    runtimeId: runtimeId,
    sdkId: sdkId,
    runtimeVersion: runtimeVersion,
    baseAppId: baseAppId,
    baseAppVersion: baseAppVersion,
    channel: CONFIG.channel,
    atomExecutableName: atomExecutableName
  })
  fs.writeFileSync(flatpakManifestPath, manifestContents)

  console.log(`Initializing flatpak build at "${flatpakBuildDirPath}"`)
  const flatpakBuilderArgs = [`--arch=${arch}`, flatpakBuildDirPath, flatpakManifestPath]
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
  const desktopEntryTemplate = fs.readFileSync(desktopTemplatePath)
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
  // FIXME: we should add {stdio: 'inherit'} but there's a bug where finish will
  // cause a flood of export warnings. This is fixed in flatpak here
  // https://github.com/flatpak/flatpak/commit/a8e1738860629465794df143a96a80295160ae83
  // and we can add output back come the next flatpak release
  spawnSync('flatpak-builder', ['--finish-only'].concat(flatpakBuilderArgs))

  console.log(`Creating special export for pixmap "${outputFlatpakFilePath}"`)
  fs.mkdirpSync(flatpakExportIconDirPath)
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'app.asar.unpacked', 'resources', 'atom.png'),
    path.join(flatpakExportIconDirPath, `${appId}.png`)
  )

  console.log(`Exporting flatpak at ${flatpakRepoDirPath}`)
  const exportArgs = ['build-export']
  if (process.env.ATOM_LINUX_FLATPAK_GPG_KEY_ID) {
    exportArgs.push('--gpg-sign', process.env.ATOM_LINUX_FLATPAK_GPG_KEY_ID)
  }
  if (process.env.ATOM_LINUX_FLATPAK_GPG_HOME_DIR) {
    exportArgs.push('--gpg-homedir', process.env.ATOM_LINUX_FLATPAK_GPG_HOME_DIR)
  }
  exportArgs.push(flatpakRepoDirPath, flatpakBuildDirPath, CONFIG.channel)
  spawnSync('flatpak', exportArgs, {stdio: 'inherit'})

  console.log(`Creating single file bundle in "${outputFlatpakFilePath}"`)
  const bundleArgs = ['build-bundle', flatpakRepoDirPath, outputFlatpakFilePath, appId, CONFIG.channel]
  spawnSync('flatpak', bundleArgs, {stdio: 'inherit'})
}
