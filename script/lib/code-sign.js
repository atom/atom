const childProcess = require('child_process')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const syncRequest = require('sync-request')

module.exports = function (packagedAppPath) {
  if (process.platform === 'darwin') {
    if (!process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL) {
      console.log('Skipping code signing because the ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL environment variable is not defined'.gray)
      return
    }

    const certPath = path.join(os.tmpdir(), 'mac.p12')
    downloadCertificate(process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL, certPath)

    try {
      console.log(`Unlocking keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN}`)
      childProcess.spawnSync('security', [
        'unlock-keychain',
        '-p', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD,
        process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
      ], {stdio: 'inherit'})

      console.log(`Importing certificate at ${certPath} into ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN} keychain`)
      childProcess.spawnSync('security', [
        'import', certPath,
        '-P', process.env.ATOM_MAC_CODE_SIGNING_CERT_PASSWORD,
        '-k', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
        '-T', '/usr/bin/codesign'
      ])

      console.log(`Code-signing application at ${packagedAppPath}`)
      childProcess.spawnSync('codesign', [
        '--deep', '--force', '--verbose',
        '--keychain', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
        '--sign', 'Developer ID Application: GitHub', packagedAppPath
      ], {stdio: 'inherit'})
    } finally {
      console.log(`Deleting certificate at ${certPath}`);
      fs.removeSync(certPath)
    }
  } else if (process.platform === 'win32') {
    const signtoolPath = path.join('C:', 'Program Files (x86)', 'Microsoft SDKs', 'Windows', 'v7.1A', 'bin', 'signtool.exe')

    const binToSignPath = path.join(packagedAppPath, 'atom.exe')
    console.log(`Signing Windows Binary at ${binToSignPath}`)
    childProcess.spawnSync(signtoolPath, [
      'sign', '/v',
      '/f', process.env.WIN_P12KEY_PATH,
      '/p', process.env.WIN_P12KEY_PASSWORD,
      binToSignPath
    ], {stdio: 'inherit'})

    // TODO: when we will be able to generate an installer, sign that too!
    // const installerToSignPath = computeInstallerPath()
    // console.log(`Signing Windows Installer at ${installerToSignPath}`)
    // childProcess.spawnSync(signtoolPath, [
    //   'sign', binToSignPath, '/v',
    //   '/f', process.env.WIN_P12KEY_PATH,
    //   '/p', process.env.WIN_P12KEY_PASSWORD
    // ], {stdio: 'inherit'})
  } else {
    throw new Error(`Code-signing is not supported for platform ${process.platform}!`)
  }
}

function downloadCertificate (downloadURL, certificatePath) {
  console.log(`Dowloading certificate to ${certificatePath}`)
  const response = syncRequest('GET', downloadURL, {
    'headers': {'Accept': 'application/vnd.github.v3.raw', 'User-Agent': 'Atom Build'}
  })

  if (response.statusCode === 200) {
    fs.writeFileSync(certificatePath, response.body)
  } else {
    throw new Error('Error downloading certificate. HTTP Status ' + response.statusCode + '.')
  }
}
