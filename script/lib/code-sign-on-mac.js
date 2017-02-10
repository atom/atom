const downloadFileFromGithub = require('./download-file-from-github')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')

module.exports = function (packagedAppPath) {
  if (!process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL && !process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH) {
    console.log('Skipping code signing because the ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL environment variable is not defined'.gray)
    return
  }

  let certPath = process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH;
  if (!certPath) {
    certPath = path.join(os.tmpdir(), 'mac.p12')
    downloadFileFromGithub(process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL, certPath)
  }
  try {
    console.log(`Unlocking keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN}`)
    const unlockArgs = ['unlock-keychain']
    // For signing on local workstations, password could be entered interactively
    if (process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD) {
      unlockArgs.push('-p', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD)
    }
    unlockArgs.push(process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN)
    spawnSync('security', unlockArgs, {stdio: 'inherit'})

    console.log(`Importing certificate at ${certPath} into ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN} keychain`)
    spawnSync('security', [
      'import', certPath,
      '-P', process.env.ATOM_MAC_CODE_SIGNING_CERT_PASSWORD,
      '-k', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
      '-T', '/usr/bin/codesign'
    ])

    console.log(`Code-signing application at ${packagedAppPath}`)
    spawnSync('codesign', [
      '--deep', '--force', '--verbose',
      '--keychain', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
      '--sign', 'Developer ID Application: GitHub', packagedAppPath
    ], {stdio: 'inherit'})
  } finally {
    if (!process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH) {
      console.log(`Deleting certificate at ${certPath}`)
      fs.removeSync(certPath)
    }
  }
}
