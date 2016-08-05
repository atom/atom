const childProcess = require('child_process')

module.exports = function (packagedAppPath) {
  if (process.platform === 'darwin') {
    console.log(`Unlocking keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN}`)
    childProcess.spawnSync('security', [
      'unlock-keychain',
      '-p', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD,
      process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
    ], {stdio: 'inherit'})

    console.log(`Code-signing application at ${packagedAppPath}`)
    childProcess.spawnSync('codesign', [
      '--deep', '--force', '--verbose',
      '--keychain', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
      '--sign', 'Developer ID Application: GitHub', packagedAppPath
    ], {stdio: 'inherit'})
  } else if (process.platform === 'win32') {
    const signtoolPath = path.join('C:', 'Program Files (x86)', 'Microsoft SDKs', 'Windows', 'v7.1A', 'bin', 'signtool.exe')

    const binToSignPath = path.join(packagedAppPath, 'atom.exe')
    console.log(`Signing Windows Binary at ${binToSignPath}`)
    childProcess.spawnSync(signtoolPath, [
      'sign', '/v',
      '/f', process.env.WIN_P12KEY_PATH,
      '/p', process.env.WIN_P12KEY_PASSWORD
    ], {stdio: 'inherit'})

    // TODO: when we will be able to generate an installer, sign that too!
    // const installerToSignPath = computeInstallerPath()
    // console.log(`Signing Windows Installer at ${installerToSignPath}`)
    // childProcess.spawnSync(signtoolPath, [
    //   'sign', '/v',
    //   '/f', process.env.WIN_P12KEY_PATH,
    //   '/p', process.env.WIN_P12KEY_PASSWORD
    // ], {stdio: 'inherit'})
  } else {
    throw new Error(`Code-signing is not supported for platform ${process.platform}!`)
  }
}
