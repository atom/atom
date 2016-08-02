const childProcess = require('child_process')

module.exports = function (packagedAppPath) {
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
}
