'use strict'

const childProcess = require('child_process')
const copySync = require('./copy-sync')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const template = require('lodash.template')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  // TODO: this logic here is duplicated (see package-application.js). Pull it
  // up in config.
  console.log(`Creating Debian package for "${packagedAppPath}"`)
  const atomExecutableName = CONFIG.channel === 'beta' ? 'atom-beta' : 'atom'
  const apmExecutableName = CONFIG.channel === 'beta' ? 'apm-beta' : 'apm'
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  const appDescription = CONFIG.appMetadata.description
  let arch
  if (process.arch === 'ia32') {
    arch = 'i386'
  } else if (process.arch === 'x64') {
    arch = 'amd64'
  } else {
    arch = process.arch
  }

  const debianPackageDirPath = path.join(os.tmpdir(), `${atomExecutableName}-${CONFIG.appMetadata.version}-${arch}`)
  const debianPackageConfigPath = path.join(debianPackageDirPath, 'DEBIAN')
  const debianPackageInstallDirPath = path.join(debianPackageDirPath, 'usr')
  const debianPackageBinDirPath = path.join(debianPackageInstallDirPath, 'bin')
  const debianPackageShareDirPath = path.join(debianPackageInstallDirPath, 'share')
  const debianPackageAtomDirPath = path.join(debianPackageShareDirPath, atomExecutableName)
  const debianPackageApplicationsDirPath = path.join(debianPackageShareDirPath, 'applications')
  const debianPackageIconsDirPath = path.join(debianPackageShareDirPath, 'pixmaps')
  const debianPackageLintianOverridesDirPath = path.join(debianPackageShareDirPath, 'lintian', 'overrides')
  const debianPackageDocsDirPath = path.join(debianPackageShareDirPath, 'doc', atomExecutableName)

  if (fs.existsSync(debianPackageDirPath)) {
    console.log(`Deleting existing build dir for Debian package at "${debianPackageDirPath}"`)
    fs.removeSync(debianPackageDirPath)
  }

  console.log('Creating Debian package structure')
  fs.mkdirpSync(debianPackageDirPath)
  fs.mkdirpSync(debianPackageConfigPath)
  fs.mkdirpSync(debianPackageInstallDirPath)
  fs.mkdirpSync(debianPackageShareDirPath)
  fs.mkdirpSync(debianPackageApplicationsDirPath)
  fs.mkdirpSync(debianPackageIconsDirPath)
  fs.mkdirpSync(debianPackageLintianOverridesDirPath)
  fs.mkdirpSync(debianPackageDocsDirPath)
  fs.mkdirpSync(debianPackageBinDirPath)

  console.log(`Copying "${packagedAppPath}" to "${debianPackageAtomDirPath}"`)
  copySync(packagedAppPath, debianPackageAtomDirPath)
  fs.chmodSync(debianPackageAtomDirPath, '755')

  console.log(`Copying binaries into "${debianPackageBinDirPath}"`)
  copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(debianPackageBinDirPath, atomExecutableName))
  fs.symlinkSync(
    path.join('..', 'share', atomExecutableName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'),
    path.join(debianPackageBinDirPath, apmExecutableName)
  )

  console.log(`Writing control file into "${debianPackageConfigPath}"`)
  const packageSizeInKilobytes = childProcess.spawnSync('du', ['-sk']).stdout.toString().split(/\s+/)[0]
  const controlFileTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'debian', 'control.in'))
  const controlFileContents = template(controlFileTemplate)({
    appFileName: atomExecutableName, version: CONFIG.appMetadata.version, arch: arch,
    installedSize: packageSizeInKilobytes, description: appDescription
  })
  fs.writeFileSync(path.join(debianPackageConfigPath, 'control'), controlFileContents)

  console.log(`Writing desktop entry file into "${debianPackageApplicationsDirPath}"`)
  const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: appName, appFileName: atomExecutableName, description: appDescription,
    installDir: '/usr', iconName: atomExecutableName
  })
  fs.writeFileSync(path.join(debianPackageApplicationsDirPath, `${atomExecutableName}.desktop`), desktopEntryContents)

  console.log(`Copying icon into "${debianPackageIconsDirPath}"`)
  copySync(
    path.join(packagedAppPath, 'resources', 'app.asar.unpacked', 'resources', 'atom.png'),
    path.join(debianPackageIconsDirPath, `${atomExecutableName}.png`)
  )

  console.log(`Copying license into "${debianPackageDocsDirPath}"`)
  copySync(
    path.join(packagedAppPath, 'resources', 'LICENSE.md'),
    path.join(debianPackageDocsDirPath, 'copyright')
  )

  console.log(`Copying lintian overrides into "${debianPackageLintianOverridesDirPath}"`)
  copySync(
    path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'debian', 'lintian-overrides'),
    path.join(debianPackageLintianOverridesDirPath, atomExecutableName)
  )

  console.log(`Generating .deb file from ${debianPackageDirPath}`)
  childProcess.spawnSync('fakeroot', ['dpkg-deb', '-b', debianPackageDirPath], {stdio: 'inherit'})

  const outputDebianPackageFilePath = path.join(CONFIG.buildOutputPath, `atom-amd64.deb`)
  console.log(`Copying generated package into "${outputDebianPackageFilePath}"`)
  copySync(`${debianPackageDirPath}.deb`, outputDebianPackageFilePath)
}
