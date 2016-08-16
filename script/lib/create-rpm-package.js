'use strict'

const copySync = require('./copy-sync')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')
const template = require('lodash.template')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  console.log(`Creating rpm package for "${packagedAppPath}"`)
  const atomExecutableName = CONFIG.channel === 'beta' ? 'atom-beta' : 'atom'
  const apmExecutableName = CONFIG.channel === 'beta' ? 'apm-beta' : 'apm'
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  const appDescription = CONFIG.appMetadata.description
  // RPM versions can't have dashes in them.
  // * http://www.rpm.org/max-rpm/ch-rpm-file-format.html
  // * https://github.com/mojombo/semver/issues/145
  const appVersion = CONFIG.appMetadata.version.replace(/-beta/, "~beta").replace(/-dev/, "~dev")
  let arch
  if (process.arch === 'ia32') {
    arch = 'i386'
  } else if (process.arch === 'x64') {
    arch = 'amd64'
  } else {
    arch = process.arch
  }

  const outputRpmPackageFilePath = path.join(CONFIG.buildOutputPath, 'atom.x86_64.rpm')
  const rpmPackageDirPath = path.join(CONFIG.homeDirPath, 'rpmbuild')
  const rpmPackageBuildDirPath = path.join(rpmPackageDirPath, 'BUILD')
  const rpmPackageSourcesDirPath = path.join(rpmPackageDirPath, 'SOURCES')
  const rpmPackageSpecsDirPath = path.join(rpmPackageDirPath, 'SPECS')
  const rpmPackageRpmsDirPath = path.join(rpmPackageDirPath, 'RPMS')
  const rpmPackageApplicationDirPath = path.join(rpmPackageBuildDirPath, appName)
  const rpmPackageIconsDirPath = path.join(rpmPackageBuildDirPath, 'icons')

  if (fs.existsSync(rpmPackageBuildDirPath)) {
    console.log(`Deleting existing rpm build directory at "${rpmPackageBuildDirPath}"`)
    fs.removeSync(rpmPackageBuildDirPath)
  }

  console.log(`Creating rpm package directory structure at "${rpmPackageDirPath}"`)
  fs.mkdirpSync(rpmPackageBuildDirPath)
  fs.mkdirpSync(rpmPackageSourcesDirPath)
  fs.mkdirpSync(rpmPackageSpecsDirPath)

  console.log(`Copying "${packagedAppPath}" to "${rpmPackageApplicationDirPath}"`)
  copySync(packagedAppPath, rpmPackageApplicationDirPath)

  console.log(`Copying icons into "${rpmPackageIconsDirPath}"`)
  copySync(
    path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'png'),
    rpmPackageIconsDirPath
  )

  console.log(`Writing rpm package spec file into "${rpmPackageSpecsDirPath}"`)
  const rpmPackageSpecFilePath = path.join(rpmPackageSpecsDirPath, 'atom.spec')
  const rpmPackageSpecsTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'redhat', 'atom.spec.in'))
  const rpmPackageSpecsContents = template(rpmPackageSpecsTemplate)({
    appName: appName, appFileName: atomExecutableName, apmFileName: apmExecutableName,
    description: appDescription, installDir: '/usr', version: appVersion
  })
  fs.writeFileSync(rpmPackageSpecFilePath, rpmPackageSpecsContents)

  console.log(`Writing desktop entry file into "${rpmPackageBuildDirPath}"`)
  const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: appName, appFileName: atomExecutableName, description: appDescription,
    installDir: '/usr', iconName: atomExecutableName
  })
  fs.writeFileSync(path.join(rpmPackageBuildDirPath, `${atomExecutableName}.desktop`), desktopEntryContents)

  console.log(`Copying atom.sh into "${rpmPackageBuildDirPath}"`)
  copySync(
    path.join(CONFIG.repositoryRootPath, 'atom.sh'),
    path.join(rpmPackageBuildDirPath, 'atom.sh')
  )

  console.log(`Generating .rpm package from "${rpmPackageDirPath}"`)
  spawnSync('rpmbuild', ['-ba', '--clean', rpmPackageSpecFilePath])

  // TODO: copy generated package into out/
  // console.log(`Copying generated package into "${outputRpmPackageFilePath}"`)
}
