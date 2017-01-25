'use strict'

const fs = require('fs-extra')
const path = require('path')
const runas = require('runas')
const template = require('lodash.template')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  const packagedAppFileName = path.basename(packagedAppPath)
  if (process.platform === 'darwin') {
    const installationDirPath = path.join(path.sep, 'Applications', packagedAppFileName)
    if (fs.existsSync(installationDirPath)) {
      console.log(`Removing previously installed "${packagedAppFileName}" at "${installationDirPath}"`)
      fs.removeSync(installationDirPath)
    }
    console.log(`Installing "${packagedAppPath}" at "${installationDirPath}"`)
    fs.copySync(packagedAppPath, installationDirPath)
  } else if (process.platform === 'win32') {
    const installationDirPath = path.join(process.env.LOCALAPPDATA, packagedAppFileName, 'app-dev')
    try {
      if (fs.existsSync(installationDirPath)) {
        console.log(`Removing previously installed "${packagedAppFileName}" at "${installationDirPath}"`)
        fs.removeSync(installationDirPath)
      }
      console.log(`Installing "${packagedAppPath}" at "${installationDirPath}"`)
      fs.copySync(packagedAppPath, installationDirPath)
    } catch (e) {
      console.log(`Administrator elevation required to install into "${installationDirPath}"`)
      const copyScriptPath = path.join(CONFIG.repositoryRootPath, 'script', 'copy-folder.cmd')
      const exitCode = runas('cmd', ['/c', copyScriptPath, packagedAppPath, installationDirPath], {admin: true})
      if (exitCode !== 0) {
        throw new Error(`Installation failed. "${copyScriptPath}" exited with status: ${exitCode}`)
      }
    }
  } else {
    const atomExecutableName = CONFIG.channel === 'beta' ? 'atom-beta' : 'atom'
    const apmExecutableName = CONFIG.channel === 'beta' ? 'apm-beta' : 'apm'
    const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
    const appDescription = CONFIG.appMetadata.description
    const userLocalDirPath = path.join('/usr', 'local')
    const shareDirPath = path.join(userLocalDirPath, 'share')
    const installationDirPath = path.join(shareDirPath, atomExecutableName)
    const applicationsDirPath = path.join(shareDirPath, 'applications')
    const desktopEntryPath = path.join(applicationsDirPath, `${atomExecutableName}.desktop`)
    const binDirPath = path.join(userLocalDirPath, 'bin')
    const atomBinDestinationPath = path.join(binDirPath, atomExecutableName)
    const apmBinDestinationPath = path.join(binDirPath, apmExecutableName)

    fs.mkdirpSync(applicationsDirPath)
    fs.mkdirpSync(binDirPath)

    if (fs.existsSync(installationDirPath)) {
      console.log(`Removing previously installed "${packagedAppFileName}" at "${installationDirPath}"`)
      fs.removeSync(installationDirPath)
    }
    console.log(`Installing "${packagedAppFileName}" at "${installationDirPath}"`)
    fs.copySync(packagedAppPath, installationDirPath)

    if (fs.existsSync(desktopEntryPath)) {
      console.log(`Removing existing desktop entry file at "${desktopEntryPath}"`)
      fs.removeSync(desktopEntryPath)
    }
    console.log(`Writing desktop entry file at "${desktopEntryPath}"`)
    const iconPath = path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'png', '1024.png')
    const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
    const desktopEntryContents = template(desktopEntryTemplate)({
      appName,
      appFileName: atomExecutableName,
      description: appDescription,
      installDir: '/usr',
      iconPath
    })
    fs.writeFileSync(desktopEntryPath, desktopEntryContents)

    if (fs.existsSync(atomBinDestinationPath)) {
      console.log(`Removing existing executable at "${atomBinDestinationPath}"`)
      fs.removeSync(atomBinDestinationPath)
    }
    console.log(`Copying atom.sh to "${atomBinDestinationPath}"`)
    fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), atomBinDestinationPath)

    try {
      fs.lstatSync(apmBinDestinationPath)
      console.log(`Removing existing executable at "${apmBinDestinationPath}"`)
      fs.removeSync(apmBinDestinationPath)
    } catch (e) { }
    console.log(`Symlinking apm to "${apmBinDestinationPath}"`)
    fs.symlinkSync(path.join('..', 'share', atomExecutableName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'), apmBinDestinationPath)

    console.log(`Changing permissions to 755 for "${installationDirPath}"`)
    fs.chmodSync(installationDirPath, '755')
  }
}
