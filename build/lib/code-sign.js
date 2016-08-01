const argv = require('yargs').argv
const childProcess = require('child_process')

module.exports = function (packagedAppPath) {
  if (!argv.codeSign) {
    console.log('Skipping code-signing. Specify --code-sign option to perform code-signing...')
    return
  }

  console.log(`Unlocking keychain ${process.env.MAC_CODE_SIGNING_KEYCHAIN}`)
  childProcess.spawnSync('security', [
    'unlock-keychain',
    '-p', process.env.MAC_CODE_SIGNING_KEYCHAIN_PASSWORD,
    process.env.MAC_CODE_SIGNING_KEYCHAIN
  ], {stdio: 'inherit'})

  console.log(`Code-signing application at ${packagedAppPath}`)
  childProcess.spawnSync('codesign', [
    '--deep', '--force', '--verbose',
    '--keychain', process.env.MAC_CODE_SIGNING_KEYCHAIN,
    '--sign', 'Developer ID Application: GitHub', packagedAppPath
  ], {stdio: 'inherit'})
}
